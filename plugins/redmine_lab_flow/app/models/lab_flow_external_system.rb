# frozen_string_literal: true

class LabFlowExternalSystem < ActiveRecord::Base
  has_many :webhooks, class_name: 'LabFlowWebhook', foreign_key: 'external_system_id', dependent: :nullify
  has_many :external_jobs, class_name: 'LabFlowExternalJob', foreign_key: 'external_system_id', dependent: :restrict_with_error

  SYSTEM_TYPES = %w[galaxy openbis custom].freeze
  AUTH_TYPES = %w[api_key oauth2 basic none].freeze
  HEALTH_STATUSES = %w[ok error unknown].freeze

  validates :name, presence: true, uniqueness: true
  validates :system_type, presence: true, inclusion: { in: SYSTEM_TYPES }
  validates :base_url, presence: true, format: { with: /\Ahttps?:\/\//i, message: 'must be a valid URL' }
  validates :auth_type, inclusion: { in: AUTH_TYPES }

  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(system_type: type) }
  scope :galaxy, -> { by_type('galaxy') }
  scope :openbis, -> { by_type('openbis') }

  serialize :configuration, coder: JSON

  def configuration
    raw = super
    return {} if raw.blank?
    raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def configuration=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  # Encrypt API key before saving
  def api_key=(value)
    self.api_key_encrypted = value.present? ? encrypt_value(value) : nil
  end

  # Decrypt API key when reading
  def api_key
    api_key_encrypted.present? ? decrypt_value(api_key_encrypted) : nil
  end

  # Encrypt API secret before saving
  def api_secret=(value)
    self.api_secret_encrypted = value.present? ? encrypt_value(value) : nil
  end

  # Decrypt API secret when reading
  def api_secret
    api_secret_encrypted.present? ? decrypt_value(api_secret_encrypted) : nil
  end

  # Check health status
  def check_health!
    url = health_check_url.presence || base_url
    response = Net::HTTP.get_response(URI(url))

    new_status = response.is_a?(Net::HTTPSuccess) ? 'ok' : 'error'
    update!(
      last_health_status: new_status,
      last_health_check_at: Time.current
    )
    new_status
  rescue StandardError => e
    update!(
      last_health_status: 'error',
      last_health_check_at: Time.current
    )
    Rails.logger.error "Health check failed for #{name}: #{e.message}"
    'error'
  end

  # Get appropriate client for this system
  def client
    case system_type
    when 'galaxy'
      RedmineLabFlow::GalaxyClient.new(self)
    when 'openbis'
      RedmineLabFlow::OpenBISClient.new(self)
    else
      RedmineLabFlow::GenericClient.new(self)
    end
  end

  private

  def encrypt_value(value)
    # Simple base64 encoding - in production, use Rails encrypted credentials
    Base64.strict_encode64(value.to_s)
  end

  def decrypt_value(encrypted)
    Base64.strict_decode64(encrypted.to_s)
  rescue ArgumentError
    encrypted
  end
end
