# frozen_string_literal: true

module RedmineLabFlow
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      # Prepend the module to override attributes_editable?
      prepend InstanceMethods

      # Validate reason for change on Daily Logs
      validate :validate_reason_for_change, on: :update
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

      # Check if the user can edit a finalized issue
      def finalized_editable_by?(user)
        return false unless user&.admin?

        settings = LabFlowProjectSetting.for_project(project)
        settings.allow_admin_unlock_finalized
      end

      # Validate that Daily Logs require a reason for change (notes)
      def validate_reason_for_change
        return unless daily_log?
        return if new_record?

        # Check if there are actual changes (journal details or notes)
        return unless @current_journal

        # If there are changes being made, notes are required
        has_changes = changed? || @current_journal.details.present?
        if has_changes && @current_journal.notes.blank?
          errors.add(:base, I18n.t(:error_reason_for_change_required))
        end
      end
    end
  end
end

# Patch application moved to init.rb after_initialize block
