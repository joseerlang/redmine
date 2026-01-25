# frozen_string_literal: true

class LabFlowExternalJob < ActiveRecord::Base
  belongs_to :issue
  belongs_to :external_system, class_name: 'LabFlowExternalSystem'
  belongs_to :submitted_by, class_name: 'User'

  JOB_TYPES = %w[workflow analysis data_import data_export sync].freeze
  STATUSES = %w[pending submitted running completed failed cancelled].freeze

  validates :issue, :external_system, :submitted_by, presence: true
  validates :job_type, inclusion: { in: JOB_TYPES }, allow_blank: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: 'pending') }
  scope :running, -> { where(status: %w[submitted running]) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :for_issue, ->(issue) { where(issue: issue) }
  scope :recent, ->(days = 7) { where('created_at >= ?', days.days.ago) }

  serialize :input_parameters, coder: JSON
  serialize :output_data, coder: JSON

  def input_parameters
    raw = super
    return {} if raw.blank?
    raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def input_parameters=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  def output_data
    raw = super
    return {} if raw.blank?
    raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def output_data=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  # State transitions
  def submit!(external_id = nil)
    update!(
      status: 'submitted',
      external_job_id: external_id,
      submitted_at: Time.current
    )
  end

  def start!
    update!(
      status: 'running',
      started_at: Time.current
    )
  end

  def complete!(output = {})
    update!(
      status: 'completed',
      output_data: output,
      completed_at: Time.current
    )
  end

  def fail!(error_msg)
    update!(
      status: 'failed',
      error_message: error_msg,
      completed_at: Time.current
    )
  end

  def cancel!
    return unless %w[pending submitted running].include?(status)

    update!(
      status: 'cancelled',
      completed_at: Time.current
    )
  end

  # Check if job can be cancelled
  def cancellable?
    %w[pending submitted running].include?(status)
  end

  # Duration in seconds
  def duration
    return nil unless started_at

    end_time = completed_at || Time.current
    (end_time - started_at).to_i
  end

  # Human-readable duration
  def human_duration
    secs = duration
    return 'N/A' unless secs

    if secs < 60
      "#{secs}s"
    elsif secs < 3600
      "#{(secs / 60).round}m"
    else
      "#{(secs / 3600.0).round(1)}h"
    end
  end

  # Refresh status from external system
  def refresh_status!
    return if %w[completed failed cancelled].include?(status)

    client = external_system.client
    external_status = client.job_status(external_job_id)

    case external_status[:state]
    when 'running'
      start! if status == 'submitted'
    when 'ok', 'completed'
      complete!(external_status[:output] || {})
    when 'error', 'failed'
      fail!(external_status[:error] || 'External job failed')
    end
  rescue StandardError => e
    Rails.logger.error "Failed to refresh job #{id}: #{e.message}"
  end
end
