# frozen_string_literal: true

class LabFlowSignaturesController < ApplicationController
  before_action :require_login
  before_action :find_issue, only: [:verify]

  accept_api_auth :verify

  # POST /lab_flow/verify_signature
  # Verifies user password and creates electronic signature
  def verify
    password = params[:password]
    meaning = params[:signature_meaning]
    new_status = params[:new_status]

    # Validate required parameters
    if password.blank? || meaning.blank?
      render_json_response(success: false, error: I18n.t(:error_signature_fields_required))
      return
    end

    # Validate signature meaning
    unless LabFlowElectronicSignature::SIGNATURE_MEANINGS.include?(meaning)
      render_json_response(success: false, error: I18n.t(:error_invalid_signature_meaning))
      return
    end

    # Get old status name for audit
    old_status = @issue.status&.name

    # Create signature with password verification
    signature = LabFlowElectronicSignature.create_with_verification(
      issue: @issue,
      user: User.current,
      password: password,
      meaning: meaning,
      source_ip: request.remote_ip,
      old_status: old_status,
      new_status: new_status
    )

    if signature
      render_json_response(
        success: true,
        signature_id: signature.id,
        message: I18n.t(:notice_signature_verified)
      )
    else
      render_json_response(success: false, error: I18n.t(:error_invalid_password))
    end
  end

  # GET /lab_flow/signatures/:issue_id
  # Returns signature history for an issue
  def index
    @issue = Issue.find(params[:issue_id])
    return render_403 unless User.current.allowed_to?(:view_issues, @issue.project)

    @signatures = LabFlowElectronicSignature.for_issue(@issue).recent.includes(:user)

    respond_to do |format|
      format.html
      format.json { render json: signatures_json }
    end
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    unless User.current.allowed_to?(:edit_issues, @issue.project)
      render json: { success: false, error: I18n.t(:notice_not_authorized) }, status: :forbidden
      return
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: I18n.t(:error_issue_not_found) }, status: :not_found
  end

  def signatures_json
    @signatures.map do |sig|
      {
        id: sig.id,
        user: sig.user.name,
        meaning: sig.meaning_label,
        signed_at: sig.signed_at.iso8601,
        old_status: sig.old_status,
        new_status: sig.new_status
      }
    end
  end

  def render_json_response(data)
    respond_to do |format|
      format.html { render json: data }
      format.json { render json: data }
      format.any { render json: data, content_type: 'application/json' }
    end
  end
end
