# frozen_string_literal: true

module RedmineLabFlow
  class Setup
    TRACKERS = [
      { key: :label_sample, desc_key: :tracker_sample_description },
      { key: :label_daily_log, desc_key: :tracker_daily_log_description },
      { key: :label_assay, desc_key: :tracker_assay_description }
    ].freeze

    # Sample tracker fields
    SAMPLE_FIELDS = [
      { key: :field_internal_id, format: 'string', required: true, filter: true, searchable: true },
      { key: :field_sample_type, format: 'list', values: %w[Biological Chemical Environmental Control Standard], filter: true },
      { key: :field_storage_location, format: 'string', filter: true },
      { key: :field_collection_date, format: 'date', filter: true },
      { key: :field_expiration_date, format: 'date', filter: true },
      { key: :field_sample_source, format: 'string', searchable: true }
    ].freeze

    # Assay tracker fields
    ASSAY_FIELDS = [
      { key: :field_measured_value, format: 'float', required: true, filter: true },
      { key: :field_unit, format: 'list', values: :configurable, filter: true },
      { key: :field_method, format: 'string', filter: true, searchable: true },
      { key: :field_instrument, format: 'string', filter: true },
      { key: :field_detection_limit, format: 'float' },
      { key: :field_uncertainty, format: 'string' }
    ].freeze

    # Daily Log tracker fields
    DAILY_LOG_FIELDS = [
      { key: :field_experiment_reference, format: 'string', required: true, searchable: true },
      { key: :field_lab_conditions, format: 'text' },
      { key: :field_equipment_used, format: 'text' },
      { key: :field_observations, format: 'text', searchable: true },
      { key: :field_protocol_version, format: 'string', filter: true },
      { key: :field_reviewed_by, format: 'user' },
      { key: :field_weather_conditions, format: 'string' },
      { key: :field_start_time, format: 'string' },
      { key: :field_end_time, format: 'string' },
      { key: :field_procedure_reference, format: 'wiki_reference', filter: true }
    ].freeze

    # Finalized status name
    FINALIZED_STATUS_KEY = :label_status_finalized

    # Phase 3: Workflow statuses for Sample/Assay lifecycle
    WORKFLOW_STATUSES = [
      { key: :label_status_accessioned, is_closed: false },
      { key: :label_status_in_analysis, is_closed: false },
      { key: :label_status_qc_pending, is_closed: false },
      { key: :label_status_completed, is_closed: true }
    ].freeze

    # Phase 3: Additional fields for inventory management
    INVENTORY_FIELDS = [
      { key: :field_lot_number, format: 'list', values: :reagent_lots, filter: true, trackers: %i[label_assay] },
      { key: :field_equipment_id, format: 'list', values: :equipment_list, filter: true, trackers: %i[label_assay label_sample] }
    ].freeze

    class << self
      def install
        return unless tables_exist?

        ActiveRecord::Base.transaction do
          create_trackers
          create_finalized_status
          create_workflow_statuses
          create_custom_fields
          create_inventory_fields
          associate_fields_with_trackers
        end
      rescue StandardError => e
        Rails.logger.error "[RedmineLabFlow] Setup failed: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
      end

      # Returns the Finalized status, or nil if not found
      def finalized_status
        IssueStatus.find_by(name: I18n.t(FINALIZED_STATUS_KEY))
      end

      # Returns the Daily Log tracker, or nil if not found
      def daily_log_tracker
        Tracker.find_by(name: I18n.t(:label_daily_log))
      end

      # Returns the Assay tracker, or nil if not found
      def assay_tracker
        Tracker.find_by(name: I18n.t(:label_assay))
      end

      # Returns the Sample tracker, or nil if not found
      def sample_tracker
        Tracker.find_by(name: I18n.t(:label_sample))
      end

      # Returns the Completed status, or nil if not found
      def completed_status
        IssueStatus.find_by(name: I18n.t(:label_status_completed))
      end

      private

      def tables_exist?
        Tracker.table_exists? && IssueCustomField.table_exists? && IssueStatus.table_exists?
      end

      def create_workflow_statuses
        WORKFLOW_STATUSES.each do |status_def|
          name = I18n.t(status_def[:key])
          next if IssueStatus.exists?(name: name)

          IssueStatus.create!(
            name: name,
            is_closed: status_def[:is_closed],
            position: IssueStatus.maximum(:position).to_i + 1
          )
          Rails.logger.info "[RedmineLabFlow] Created workflow status: #{name}"
        end
      end

      def create_finalized_status
        name = I18n.t(FINALIZED_STATUS_KEY)
        return if IssueStatus.exists?(name: name)

        IssueStatus.create!(
          name: name,
          is_closed: true,
          position: IssueStatus.maximum(:position).to_i + 1
        )
        Rails.logger.info "[RedmineLabFlow] Created status: #{name}"
      end

      def create_trackers
        default_status = IssueStatus.sorted.first
        return unless default_status

        TRACKERS.each do |tracker_def|
          name = I18n.t(tracker_def[:key])
          next if Tracker.exists?(name: name)

          Tracker.create!(
            name: name,
            description: I18n.t(tracker_def[:desc_key]),
            default_status_id: default_status.id,
            position: Tracker.maximum(:position).to_i + 1
          )
          Rails.logger.info "[RedmineLabFlow] Created tracker: #{name}"
        end
      end

      def create_custom_fields
        create_fields_for_tracker(SAMPLE_FIELDS)
        create_fields_for_tracker(ASSAY_FIELDS)
        create_fields_for_tracker(DAILY_LOG_FIELDS)
      end

      def create_inventory_fields
        return unless LabReagent.table_exists? && LabEquipment.table_exists?

        INVENTORY_FIELDS.each do |field_def|
          name = I18n.t(field_def[:key])
          next if IssueCustomField.exists?(name: name)

          attrs = {
            name: name,
            field_format: field_def[:format],
            is_required: false,
            is_for_all: true,
            is_filter: field_def[:filter] || false
          }

          # Handle dynamic list values
          if field_def[:format] == 'list'
            attrs[:possible_values] = case field_def[:values]
                                      when :reagent_lots
                                        reagent_lot_values
                                      when :equipment_list
                                        equipment_values
                                      else
                                        []
                                      end
          end

          field = IssueCustomField.create!(attrs)
          Rails.logger.info "[RedmineLabFlow] Created inventory field: #{name}"

          # Associate with specific trackers
          field_def[:trackers]&.each do |tracker_key|
            tracker = Tracker.find_by(name: I18n.t(tracker_key))
            next unless tracker
            next if tracker.custom_fields.include?(field)

            tracker.custom_fields << field
          end
        end
      end

      def reagent_lot_values
        return [] unless LabReagent.table_exists?

        LabReagent.active.sorted.map(&:display_name)
      end

      def equipment_values
        return [] unless LabEquipment.table_exists?

        LabEquipment.active.sorted.map(&:display_name)
      end

      def create_fields_for_tracker(fields_config)
        fields_config.each do |field_def|
          name = I18n.t(field_def[:key])
          next if IssueCustomField.exists?(name: name)

          attrs = {
            name: name,
            field_format: field_def[:format],
            is_required: field_def[:required] || false,
            is_for_all: true,
            is_filter: field_def[:filter] || false,
            searchable: field_def[:searchable] || false
          }

          # Handle list values
          if field_def[:format] == 'list'
            attrs[:possible_values] = if field_def[:values] == :configurable
                                        configurable_units
                                      else
                                        field_def[:values]
                                      end
          end

          IssueCustomField.create!(attrs)
          Rails.logger.info "[RedmineLabFlow] Created custom field: #{name}"
        end
      end

      def configurable_units
        settings = Setting.plugin_redmine_lab_flow rescue {}
        (settings['units'] || "units\nmg\nml").split("\n").map(&:strip).reject(&:empty?)
      end

      def associate_fields_with_trackers
        associate_tracker_fields(:label_sample, SAMPLE_FIELDS)
        associate_tracker_fields(:label_assay, ASSAY_FIELDS)
        associate_tracker_fields(:label_daily_log, DAILY_LOG_FIELDS)
      end

      def associate_tracker_fields(tracker_key, fields_config)
        tracker = Tracker.find_by(name: I18n.t(tracker_key))
        return unless tracker

        fields_config.each do |field_def|
          field = IssueCustomField.find_by(name: I18n.t(field_def[:key]))
          next unless field
          next if tracker.custom_fields.include?(field)

          tracker.custom_fields << field
          Rails.logger.info "[RedmineLabFlow] Associated field '#{field.name}' with tracker '#{tracker.name}'"
        end
      end
    end
  end
end
