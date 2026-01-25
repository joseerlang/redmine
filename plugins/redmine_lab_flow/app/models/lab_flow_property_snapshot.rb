# frozen_string_literal: true

class LabFlowPropertySnapshot < ActiveRecord::Base
  belongs_to :issue
  belongs_to :journal, optional: true
  belongs_to :sequence, class_name: 'LabFlowSequence', optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  TRIGGER_EVENTS = %w[
    status_change
    custom_field_update
    attachment_added
    manual
    initial
  ].freeze

  validates :issue, :snapshot_data, presence: true
  validates :trigger_event, inclusion: { in: TRIGGER_EVENTS }, allow_blank: true

  scope :for_issue, ->(issue) { where(issue: issue).order(created_at: :asc) }
  scope :recent, ->(count = 10) { order(created_at: :desc).limit(count) }
  scope :by_event, ->(event) { where(trigger_event: event) }

  serialize :snapshot_data, coder: JSON

  def snapshot_data
    raw = super
    return {} if raw.blank?
    raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def snapshot_data=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  # Create a snapshot from current issue state
  def self.create_from_issue(issue, trigger: 'manual', user: nil, journal: nil)
    data = build_snapshot_data(issue)

    create!(
      issue: issue,
      journal: journal,
      snapshot_data: data,
      molecule_smiles: extract_molecule_smiles(issue),
      created_by: user || User.current,
      trigger_event: trigger
    )
  end

  # Build snapshot data hash from issue
  def self.build_snapshot_data(issue)
    {
      'status' => {
        'id' => issue.status_id,
        'name' => issue.status.name
      },
      'tracker' => {
        'id' => issue.tracker_id,
        'name' => issue.tracker.name
      },
      'priority' => {
        'id' => issue.priority_id,
        'name' => issue.priority.name
      },
      'assigned_to' => issue.assigned_to ? {
        'id' => issue.assigned_to_id,
        'name' => issue.assigned_to.name
      } : nil,
      'custom_fields' => issue.custom_field_values.each_with_object({}) do |cfv, hash|
        hash[cfv.custom_field.name] = {
          'id' => cfv.custom_field_id,
          'value' => cfv.value
        }
      end,
      'updated_on' => issue.updated_on.iso8601,
      'due_date' => issue.due_date&.iso8601
    }
  end

  # Extract molecule SMILES from issue custom fields
  def self.extract_molecule_smiles(issue)
    molecule_field = issue.custom_field_values.find { |cfv| cfv.custom_field.field_format == 'molecule' }
    molecule_field&.value
  end

  # Compare with another snapshot
  def diff(other_snapshot)
    return {} unless other_snapshot.is_a?(LabFlowPropertySnapshot)

    changes = {}

    snapshot_data.each do |key, value|
      other_value = other_snapshot.snapshot_data[key]
      if value != other_value
        changes[key] = {
          'from' => other_value,
          'to' => value
        }
      end
    end

    # Check for keys only in other snapshot
    other_snapshot.snapshot_data.each do |key, value|
      unless snapshot_data.key?(key)
        changes[key] = {
          'from' => value,
          'to' => nil
        }
      end
    end

    changes
  end

  # Get status at this snapshot
  def status_name
    snapshot_data.dig('status', 'name')
  end

  # Get custom field value at this snapshot
  def custom_field_value(field_name)
    snapshot_data.dig('custom_fields', field_name, 'value')
  end

  # Human-readable summary of what changed
  def change_summary
    return 'Initial snapshot' if trigger_event == 'initial'

    case trigger_event
    when 'status_change'
      "Status changed to #{status_name}"
    when 'custom_field_update'
      'Custom fields updated'
    when 'attachment_added'
      'Attachment added'
    else
      'Manual snapshot'
    end
  end
end
