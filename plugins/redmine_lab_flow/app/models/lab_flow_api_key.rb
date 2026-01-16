# frozen_string_literal: true

class LabFlowApiKey < ApplicationRecord
  include Redmine::SafeAttributes

  belongs_to :project
  belongs_to :created_by, class_name: 'User'

  validates :project_id, presence: true
  validates :created_by_id, presence: true
  validates :api_key, presence: true, uniqueness: true

  safe_attributes 'description', 'active'

  scope :active, -> { where(active: true) }
  scope :for_project, ->(project) { where(project: project) }
  scope :sorted, -> { order(created_at: :desc) }

  before_validation :generate_api_key, on: :create

  # Find API key by token and update last_used_at
  def self.find_and_touch(token)
    return nil if token.blank?

    key = active.find_by(api_key: token)
    key&.touch(:last_used_at)
    key
  end

  # Authenticate request using API key or user token
  def self.authenticate(request)
    # Try X-API-Key header first (project-level key)
    api_key_header = request.headers['X-API-Key'] || request.headers['X-Api-Key']
    if api_key_header.present?
      api_key = find_and_touch(api_key_header)
      return { type: :project, project: api_key.project, api_key: api_key } if api_key
    end

    # Try Redmine user API token (X-Redmine-API-Key header or key param)
    user_token = request.headers['X-Redmine-API-Key'] || request.params[:key]
    if user_token.present?
      user = User.find_by_api_key(user_token)
      return { type: :user, user: user } if user&.active?
    end

    nil
  end

  # Masked API key for display
  def masked_key
    return '' if api_key.blank?

    "#{api_key[0..7]}...#{api_key[-4..]}"
  end

  # Check if key was used recently
  def recently_used?
    last_used_at.present? && last_used_at > 24.hours.ago
  end

  private

  def generate_api_key
    self.api_key ||= SecureRandom.hex(32)
  end
end
