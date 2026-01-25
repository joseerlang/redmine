# frozen_string_literal: true

class LabFlowWebhook < ActiveRecord::Base
  belongs_to :project
  belongs_to :external_system, class_name: 'LabFlowExternalSystem', optional: true

  EVENT_TYPES = %w[
    issue.created
    issue.updated
    status.changed
    assay.completed
    sample.accessioned
    experiment.finalized
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :target_url, presence: true, format: { with: /\Ahttps?:\/\//i, message: 'must be a valid URL' }
  validates :retry_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }

  scope :active, -> { where(active: true) }
  scope :for_project, ->(project) { where(project: project) }
  scope :for_event, ->(event) { where(event_type: event) }

  before_create :generate_secret_token

  # Render payload using Liquid template
  def render_payload(data)
    template_content = payload_template.presence || default_payload_template
    template = Liquid::Template.parse(template_content)
    JSON.parse(template.render(data.deep_stringify_keys))
  rescue Liquid::Error, JSON::ParserError => e
    Rails.logger.error "Webhook payload error: #{e.message}"
    data
  end

  # Trigger this webhook with data
  def trigger!(data)
    return unless active?

    payload = render_payload(data)
    RedmineLabFlow::WebhookDispatcher.dispatch(self, payload)

    update!(last_triggered_at: Time.current)
  rescue StandardError => e
    update!(last_status: 'failed', last_error: e.message)
    raise
  end

  # Update status after dispatch
  def record_success!
    update!(last_status: 'success', last_error: nil)
  end

  def record_failure!(error_message)
    update!(last_status: 'failed', last_error: error_message)
  end

  private

  def generate_secret_token
    self.secret_token ||= SecureRandom.hex(32)
  end

  def default_payload_template
    <<~LIQUID
      {
        "event": "{{ event_type }}",
        "timestamp": "{{ timestamp }}",
        "issue": {
          "id": {{ issue.id }},
          "subject": "{{ issue.subject }}",
          "status": "{{ issue.status.name }}",
          "tracker": "{{ issue.tracker.name }}"
        },
        "project": {
          "id": {{ project.id }},
          "identifier": "{{ project.identifier }}"
        }
      }
    LIQUID
  end
end
