# frozen_string_literal: true

class LabFlowExternalSystemsController < ApplicationController
  before_action :require_admin
  before_action :find_system, only: [:show, :edit, :update, :destroy, :health_check]

  def index
    @systems = LabFlowExternalSystem.order(:name)
  end

  def show
    @recent_jobs = LabFlowExternalJob.where(external_system: @system)
                                     .order(created_at: :desc)
                                     .limit(10)
  end

  def new
    @system = LabFlowExternalSystem.new
  end

  def create
    @system = LabFlowExternalSystem.new(system_params)

    if @system.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to lab_flow_external_systems_path
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @system.update(system_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to lab_flow_external_systems_path
    else
      render :edit
    end
  end

  def destroy
    if @system.external_jobs.any?
      flash[:error] = 'Cannot delete system with existing jobs'
      redirect_to lab_flow_external_systems_path
    else
      @system.destroy
      flash[:notice] = l(:notice_successful_delete)
      redirect_to lab_flow_external_systems_path
    end
  end

  def health_check
    status = @system.check_health!

    respond_to do |format|
      format.html do
        if status == 'ok'
          flash[:notice] = "#{@system.name} is healthy"
        else
          flash[:error] = "#{@system.name} health check failed"
        end
        redirect_to lab_flow_external_systems_path
      end
      format.json do
        render json: {
          status: status,
          checked_at: @system.last_health_check_at
        }
      end
    end
  end

  private

  def find_system
    @system = LabFlowExternalSystem.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def system_params
    params.require(:lab_flow_external_system).permit(
      :name, :system_type, :base_url,
      :api_key, :api_secret,
      :auth_type, :health_check_url, :active
    ).tap do |p|
      # Handle configuration as JSON
      if params[:lab_flow_external_system][:configuration].present?
        p[:configuration] = JSON.parse(params[:lab_flow_external_system][:configuration])
      end
    rescue JSON::ParserError
      p[:configuration] = {}
    end
  end
end
