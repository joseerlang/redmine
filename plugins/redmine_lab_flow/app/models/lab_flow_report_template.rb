# frozen_string_literal: true

class LabFlowReportTemplate < ActiveRecord::Base
  belongs_to :tracker, optional: true

  has_many :generated_reports, class_name: 'LabFlowGeneratedReport', foreign_key: 'report_template_id', dependent: :destroy

  REPORT_TYPES = %w[experiment sample_batch assay_summary compliance custom].freeze

  validates :name, presence: true, uniqueness: true
  validates :report_type, presence: true, inclusion: { in: REPORT_TYPES }

  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(report_type: type) }
  scope :for_tracker, ->(tracker) { where(tracker: tracker).or(where(tracker: nil)) }

  serialize :fields_to_include, coder: JSON

  def fields_to_include
    raw = super
    return [] if raw.blank?
    raw.is_a?(Array) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    []
  end

  def fields_to_include=(value)
    super(value.is_a?(Array) ? value.to_json : value)
  end

  # Render template with Liquid
  def render(context_data)
    return '' if template_content.blank?

    template = Liquid::Template.parse(template_content)
    template.render(context_data.deep_stringify_keys)
  rescue Liquid::Error => e
    Rails.logger.error "Liquid template error: #{e.message}"
    "Template Error: #{e.message}"
  end

  # Available variables for templates
  def self.available_variables
    {
      'issue' => %w[id subject description created_on updated_on due_date],
      'project' => %w[id name identifier description],
      'author' => %w[name login mail],
      'status' => %w[name],
      'tracker' => %w[name],
      'custom_fields' => 'Dynamic based on issue custom field values',
      'signatures' => 'Array of electronic signatures if include_signatures is true',
      'eln_content' => 'Wiki page content if include_eln_narrative is true'
    }
  end
end
