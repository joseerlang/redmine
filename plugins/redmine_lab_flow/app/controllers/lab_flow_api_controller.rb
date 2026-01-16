# frozen_string_literal: true

class LabFlowApiController < ApplicationController
  # Skip standard authentication - we use API keys
  skip_before_action :check_if_login_required
  before_action :authenticate_api_request
  before_action :find_assay_by_internal_id, only: [:show_assay, :update_assay]

  # GET /lab_flow_api/assays/:internal_id
  # Retrieve an Assay by its Internal ID
  def show_assay
    render json: assay_to_json(@assay)
  end

  # POST /lab_flow_api/assays/:internal_id
  # Update an Assay with data from external instruments
  def update_assay
    # Set source type to API
    set_source_type_to_api(@assay)

    # Update custom field values
    if params[:custom_fields].present?
      update_custom_fields(@assay, params[:custom_fields])
    end

    # Update standard fields if provided
    @assay.subject = params[:subject] if params[:subject].present?
    @assay.description = params[:description] if params[:description].present?

    # Add journal note for audit trail
    @assay.init_journal(api_user, params[:notes] || I18n.t(:text_api_update_note))

    if @assay.save
      render json: {
        success: true,
        issue_id: @assay.id,
        internal_id: params[:internal_id],
        message: I18n.t(:notice_assay_updated_via_api)
      }
    else
      render json: {
        success: false,
        errors: @assay.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /lab_flow_api/projects/:project_id/assays
  # List all Assays for a project
  def list_assays
    project = find_project_by_identifier_or_id(params[:project_id])
    return render_project_not_found unless project

    assay_tracker = RedmineLabFlow::Setup.assay_tracker
    return render json: { error: 'Assay tracker not configured' }, status: :not_found unless assay_tracker

    assays = Issue.where(project: project, tracker: assay_tracker)
                  .order(created_on: :desc)
                  .limit(params[:limit] || 100)
                  .offset(params[:offset] || 0)

    render json: {
      total_count: Issue.where(project: project, tracker: assay_tracker).count,
      assays: assays.map { |a| assay_to_json(a) }
    }
  end

  private

  def authenticate_api_request
    @auth_result = LabFlowApiKey.authenticate(request)

    unless @auth_result
      render json: {
        error: I18n.t(:error_api_authentication_failed),
        hint: 'Provide X-API-Key (project key) or X-Redmine-API-Key (user token) header'
      }, status: :unauthorized
    end
  end

  def find_assay_by_internal_id
    internal_id = params[:internal_id]
    assay_tracker = RedmineLabFlow::Setup.assay_tracker

    unless assay_tracker
      render json: { error: 'Assay tracker not configured' }, status: :not_found
      return
    end

    # Find the Internal ID custom field
    internal_id_field = IssueCustomField.find_by(name: I18n.t(:field_internal_id))
    unless internal_id_field
      render json: { error: 'Internal ID field not configured' }, status: :not_found
      return
    end

    # Find the assay by Internal ID custom field value
    @assay = Issue.joins(:custom_values)
                  .where(tracker: assay_tracker)
                  .where(custom_values: { custom_field_id: internal_id_field.id, value: internal_id })
                  .first

    unless @assay
      render json: { error: "Assay with Internal ID '#{internal_id}' not found" }, status: :not_found
      return
    end

    # Verify project access for project-level API keys
    if @auth_result[:type] == :project && @assay.project_id != @auth_result[:project].id
      render json: { error: 'Access denied to this project' }, status: :forbidden
    end
  end

  def api_user
    case @auth_result[:type]
    when :user
      @auth_result[:user]
    when :project
      # Use the user who created the API key, or system user
      @auth_result[:api_key].created_by || User.anonymous
    end
  end

  def set_source_type_to_api(issue)
    source_type_field = IssueCustomField.find_by(name: I18n.t(:field_source_type))
    return unless source_type_field

    issue.custom_field_values = { source_type_field.id => 'api' }
  end

  def update_custom_fields(issue, custom_fields_params)
    custom_fields_params.each do |field_name, value|
      field = IssueCustomField.find_by(name: field_name)
      next unless field

      # Don't allow updating source_type via API
      next if field.name == I18n.t(:field_source_type)

      issue.custom_field_values = { field.id => value }
    end
  end

  def assay_to_json(issue)
    internal_id_field = IssueCustomField.find_by(name: I18n.t(:field_internal_id))

    {
      id: issue.id,
      internal_id: internal_id_field ? issue.custom_field_value(internal_id_field) : nil,
      subject: issue.subject,
      status: issue.status.name,
      project: issue.project.identifier,
      created_on: issue.created_on.iso8601,
      updated_on: issue.updated_on.iso8601,
      custom_fields: issue.custom_field_values.map do |cfv|
        {
          name: cfv.custom_field.name,
          value: cfv.value
        }
      end
    }
  end

  def find_project_by_identifier_or_id(identifier)
    Project.find_by(identifier: identifier) || Project.find_by(id: identifier)
  end

  def render_project_not_found
    render json: { error: 'Project not found' }, status: :not_found
  end
end
