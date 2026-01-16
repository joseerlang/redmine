# frozen_string_literal: true

module RedmineLabFlow
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      # Prepend the module to override attributes_editable?
      prepend InstanceMethods

      # Validate reason for change on Daily Logs and Assays
      validate :validate_reason_for_change_on_daily_log, on: :update
      validate :validate_reason_for_change_on_assay, on: :update

      # Validate expired reagents on Assay completion
      validate :validate_reagent_not_expired_on_completion

      # Phase 4: Validate electronic signature for status changes
      validate :validate_electronic_signature_for_status_change, on: :update

      # Phase 4: Track signature verification state
      attr_accessor :signature_verified
    end

    module InstanceMethods
      # Override attributes_editable? to handle finalized Daily Logs
      def attributes_editable?(user = User.current)
        # Check if this is a finalized Daily Log
        return super unless finalized_daily_log?

        # Finalized Daily Logs are not editable by default
        return false unless finalized_editable_by?(user)

        # Admin with permission can still edit
        super
      end

      # Check if this issue is a finalized Daily Log
      def finalized_daily_log?
        finalized? && daily_log?
      end

      # Check if this issue is finalized
      def finalized?
        finalized_status = RedmineLabFlow::Setup.finalized_status
        return false unless finalized_status

        status_id == finalized_status.id
      end

      # Check if this issue is a Daily Log
      def daily_log?
        daily_log_tracker = RedmineLabFlow::Setup.daily_log_tracker
        return false unless daily_log_tracker

        tracker_id == daily_log_tracker.id
      end

      # Check if this issue is an Assay
      def assay?
        assay_tracker = RedmineLabFlow::Setup.assay_tracker
        return false unless assay_tracker

        tracker_id == assay_tracker.id
      end

      # Check if this issue is a Sample
      def sample?
        sample_tracker = RedmineLabFlow::Setup.sample_tracker
        return false unless sample_tracker

        tracker_id == sample_tracker.id
      end

      # Check if issue is being moved to Completed status
      def completing?
        return false unless status_id_changed?

        completed_status = RedmineLabFlow::Setup.completed_status
        return false unless completed_status

        status_id == completed_status.id
      end

      # Phase 4: Check if issue is being moved to Verified status
      def verifying?
        return false unless status_id_changed?

        verified_status = RedmineLabFlow::Setup.verified_status
        return false unless verified_status

        status_id == verified_status.id
      end

      # Phase 4: Check if status change requires electronic signature
      def requires_signature?
        return false unless status_id_changed?
        return false unless assay? || sample?

        new_status = IssueStatus.find_by(id: status_id)
        RedmineLabFlow::Setup.status_requires_signature?(new_status)
      end

      # Phase 4: Check if a recent electronic signature exists for this status change
      def has_recent_signature?(user = User.current)
        return false unless LabFlowElectronicSignature.table_exists?

        LabFlowElectronicSignature.recent_signature_for(self, user, seconds: 300).present?
      end

      # Check if the user can edit a finalized issue
      def finalized_editable_by?(user)
        return false unless user&.admin?

        settings = LabFlowProjectSetting.for_project(project)
        settings.allow_admin_unlock_finalized
      end

      private

      # Validate that Daily Logs require a reason for change (notes)
      def validate_reason_for_change_on_daily_log
        return unless daily_log?
        return if new_record?

        # Only validate if there's a journal being created with changes
        journal = current_journal
        return unless journal

        # Check if there are actual changes being made
        has_changes = changed? || journal.details.present?
        return unless has_changes

        # Check if notes are provided
        if journal.notes.blank?
          errors.add(:base, I18n.t(:error_reason_for_change_required))
        end
      end

      # Validate that Assays require a reason for change (notes)
      def validate_reason_for_change_on_assay
        return unless assay?
        return if new_record?

        # Only validate if there's a journal being created with changes
        journal = current_journal
        return unless journal

        # Check if there are actual changes being made
        has_changes = changed? || journal.details.present?
        return unless has_changes

        # Check if notes are provided
        if journal.notes.blank?
          errors.add(:base, I18n.t(:error_reason_for_change_required_assay))
        end
      end

      # Validate that Assays cannot be completed with expired reagents
      def validate_reagent_not_expired_on_completion
        return unless assay?
        return unless completing?
        return unless LabReagent.table_exists?

        # Find the Lot Number custom field
        lot_field = IssueCustomField.find_by(name: I18n.t(:field_lot_number))
        return unless lot_field

        lot_value = custom_field_value(lot_field)
        return if lot_value.blank?

        # Find the reagent by lot display name
        reagent = LabReagent.active.find { |r| r.display_name == lot_value }
        return unless reagent

        if reagent.expired?
          errors.add(:base, I18n.t(:error_reagent_expired, lot: reagent.lot_number, expiration: reagent.expiration_date))
        end
      end

      # Phase 4: Validate that electronic signature exists for status changes to Verified/Completed
      def validate_electronic_signature_for_status_change
        return unless requires_signature?
        return unless LabFlowElectronicSignature.table_exists?

        # Skip if signature was verified in this request (set by controller)
        return if signature_verified

        # Check if there's a recent signature
        return if has_recent_signature?

        errors.add(:base, I18n.t(:error_signature_required))
      end
    end
  end
end

# Patch application moved to init.rb after_initialize block
