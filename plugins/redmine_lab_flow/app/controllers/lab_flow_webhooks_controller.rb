# frozen_string_literal: true

class LabFlowWebhooksController < ApplicationController
  before_action :find_project
  before_action :authorize
  before_action :find_webhook, only: [:show, :edit, :update, :destroy, :test]

  def index
    @webhooks = LabFlowWebhook.for_project(@project).includes(:external_system)
  end

  def show
  end

  def new
    @webhook = LabFlowWebhook.new(project: @project)
    @external_systems = LabFlowExternalSystem.active
  end

  def create
    @webhook = LabFlowWebhook.new(webhook_params)
    @webhook.project = @project

    if @webhook.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to project_lab_flow_webhooks_path(@project)
    else
      @external_systems = LabFlowExternalSystem.active
      render :new
    end
  end

  def edit
    @external_systems = LabFlowExternalSystem.active
  end

  def update
    if @webhook.update(webhook_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to project_lab_flow_webhooks_path(@project)
    else
      @external_systems = LabFlowExternalSystem.active
      render :edit
    end
  end

  def destroy
    @webhook.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to project_lab_flow_webhooks_path(@project)
  end

  def test
    # Send a test payload to the webhook
    test_data = {
      'event_type' => @webhook.event_type,
      'timestamp' => Time.current.iso8601,
      'test' => true,
      'issue' => {
        'id' => 0,
        'subject' => 'Test Issue',
        'status' => { 'name' => 'New' },
        'tracker' => { 'name' => 'Sample' }
      },
      'project' => {
        'id' => @project.id,
        'identifier' => @project.identifier
      }
    }

    begin
      RedmineLabFlow::WebhookDispatcher.dispatch(@webhook, @webhook.render_payload(test_data))
      @webhook.record_success!
      flash[:notice] = 'Test webhook sent successfully'
    rescue StandardError => e
      @webhook.record_failure!(e.message)
      flash[:error] = "Test webhook failed: #{e.message}"
    end

    redirect_to project_lab_flow_webhooks_path(@project)
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_webhook
    @webhook = LabFlowWebhook.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def webhook_params
    params.require(:lab_flow_webhook).permit(
      :external_system_id, :event_type, :target_url,
      :secret_token, :payload_template, :retry_count, :active
    )
  end
end
