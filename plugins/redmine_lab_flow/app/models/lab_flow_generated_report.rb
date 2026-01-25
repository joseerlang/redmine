# frozen_string_literal: true

class LabFlowGeneratedReport < ActiveRecord::Base
  belongs_to :report_template, class_name: 'LabFlowReportTemplate'
  belongs_to :issue, optional: true
  belongs_to :project
  belongs_to :generated_by, class_name: 'User'

  FORMATS = %w[pdf xlsx json html].freeze
  STATUSES = %w[pending generating completed failed].freeze

  validates :format, presence: true, inclusion: { in: FORMATS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :project, :report_template, :generated_by, presence: true

  scope :recent, ->(days = 30) { where('created_at >= ?', days.days.ago) }
  scope :by_format, ->(fmt) { where(format: fmt) }
  scope :completed, -> { where(status: 'completed') }
  scope :for_issue, ->(issue) { where(issue: issue) }

  serialize :parameters, coder: JSON

  def parameters
    raw = super
    return {} if raw.blank?
    raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def parameters=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  # Full path to generated file
  def full_file_path
    return nil if file_path.blank?

    Rails.root.join('files', 'lab_flow_reports', file_path)
  end

  # Check if file exists and is downloadable
  def downloadable?
    status == 'completed' && file_path.present? && File.exist?(full_file_path.to_s)
  end

  # Human-readable file size
  def human_file_size
    return 'N/A' unless file_size.present? && file_size > 0

    if file_size < 1024
      "#{file_size} B"
    elsif file_size < 1024 * 1024
      "#{(file_size / 1024.0).round(1)} KB"
    else
      "#{(file_size / (1024.0 * 1024)).round(2)} MB"
    end
  end

  # Mark as generating
  def start_generation!
    update!(status: 'generating')
  end

  # Mark as completed with file
  def complete!(path, size)
    update!(
      status: 'completed',
      file_path: path,
      file_size: size
    )
  end

  # Mark as failed
  def fail!(message)
    update!(
      status: 'failed',
      error_message: message
    )
  end
end
