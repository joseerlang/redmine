# frozen_string_literal: true

class LabFlowElectronicSignature < ApplicationRecord
  include Redmine::SafeAttributes

  # Signature meanings for compliance
  SIGNATURE_MEANINGS = %w[authorship review approval].freeze

  belongs_to :issue
  belongs_to :user

  validates :issue_id, presence: true
  validates :user_id, presence: true
  validates :signature_meaning, presence: true, inclusion: { in: SIGNATURE_MEANINGS }
  validates :signed_at, presence: true

  safe_attributes 'signature_meaning'

  scope :for_issue, ->(issue) { where(issue: issue) }
  scope :recent, -> { order(signed_at: :desc) }
  scope :by_meaning, ->(meaning) { where(signature_meaning: meaning) }

  before_validation :set_signed_at, on: :create

  # Check if user has a valid signature for this issue within the last few seconds
  # Used to verify that user signed before status change
  def self.recent_signature_for(issue, user, seconds: 60)
    where(issue: issue, user: user)
      .where('signed_at > ?', seconds.seconds.ago)
      .order(signed_at: :desc)
      .first
  end

  # Create a signature after verifying password
  def self.create_with_verification(issue:, user:, password:, meaning:, source_ip: nil, old_status: nil, new_status: nil)
    return nil unless user.check_password?(password)

    create(
      issue: issue,
      user: user,
      signature_meaning: meaning,
      source_ip: source_ip,
      old_status: old_status,
      new_status: new_status
    )
  end

  # Human-readable signature meaning
  def meaning_label
    I18n.t("label_signature_meaning_#{signature_meaning}", default: signature_meaning.titleize)
  end

  # Formatted signature info for audit trail
  def audit_info
    "#{user.name} (#{meaning_label}) - #{I18n.l(signed_at, format: :long)}"
  end

  # Check if signature is verified (all required fields present)
  def verified?
    user_id.present? && signed_at.present? && signature_meaning.present?
  end

  # Comments/notes on the signature (optional field)
  def comments
    read_attribute(:comments) || nil
  end

  private

  def set_signed_at
    self.signed_at ||= Time.current
  end
end
