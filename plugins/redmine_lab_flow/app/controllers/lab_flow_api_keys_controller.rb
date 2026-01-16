# frozen_string_literal: true

class LabFlowApiKeysController < ApplicationController
  before_action :require_admin
  before_action :find_api_key, only: [:show, :update, :destroy, :regenerate]

  # GET /lab_flow_api_keys
  def index
    @api_keys = LabFlowApiKey.includes(:project, :created_by).sorted
  end

  # GET /lab_flow_api_keys/:id
  def show
    respond_to do |format|
      format.html
      format.json { render json: api_key_json(@api_key) }
    end
  end

  # POST /lab_flow_api_keys
  def create
    @api_key = LabFlowApiKey.new(api_key_params)
    @api_key.created_by = User.current

    if @api_key.save
      flash[:notice] = I18n.t(:notice_api_key_created)
      respond_to do |format|
        format.html { redirect_to_settings }
        format.json { render json: api_key_json(@api_key, include_key: true), status: :created }
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = @api_key.errors.full_messages.join(', ')
          redirect_to_settings
        end
        format.json { render json: { errors: @api_key.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /lab_flow_api_keys/:id
  def update
    if @api_key.update(api_key_params)
      flash[:notice] = I18n.t(:notice_api_key_updated)
      respond_to do |format|
        format.html { redirect_to_settings }
        format.json { render json: api_key_json(@api_key) }
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = @api_key.errors.full_messages.join(', ')
          redirect_to_settings
        end
        format.json { render json: { errors: @api_key.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lab_flow_api_keys/:id
  def destroy
    @api_key.destroy
    flash[:notice] = I18n.t(:notice_api_key_deleted)
    respond_to do |format|
      format.html { redirect_to_settings }
      format.json { head :no_content }
    end
  end

  # POST /lab_flow_api_keys/:id/regenerate
  def regenerate
    old_key = @api_key.api_key
    @api_key.update!(api_key: SecureRandom.hex(32))

    flash[:notice] = I18n.t(:notice_api_key_regenerated)
    respond_to do |format|
      format.html { redirect_to_settings }
      format.json { render json: api_key_json(@api_key, include_key: true) }
    end
  end

  private

  def find_api_key
    @api_key = LabFlowApiKey.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def api_key_params
    params.require(:lab_flow_api_key).permit(:project_id, :description, :active)
  end

  def redirect_to_settings
    redirect_to plugin_settings_path('redmine_lab_flow', tab: 'api_keys')
  end

  def api_key_json(api_key, include_key: false)
    json = {
      id: api_key.id,
      project: api_key.project.name,
      project_identifier: api_key.project.identifier,
      description: api_key.description,
      active: api_key.active,
      created_by: api_key.created_by.name,
      created_at: api_key.created_at.iso8601,
      last_used_at: api_key.last_used_at&.iso8601,
      masked_key: api_key.masked_key
    }
    json[:api_key] = api_key.api_key if include_key
    json
  end
end
