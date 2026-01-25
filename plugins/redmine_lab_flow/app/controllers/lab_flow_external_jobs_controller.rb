# frozen_string_literal: true

class LabFlowExternalJobsController < ApplicationController
  before_action :find_issue
  before_action :authorize
  before_action :find_job, only: [:show, :cancel]

  def index
    @jobs = LabFlowExternalJob.for_issue(@issue)
                              .includes(:external_system, :submitted_by)
                              .order(created_at: :desc)

    respond_to do |format|
      format.html
      format.json { render json: jobs_json(@jobs) }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: job_json(@job) }
    end
  end

  def create
    @system = LabFlowExternalSystem.find(params[:external_system_id])

    @job = LabFlowExternalJob.new(
      issue: @issue,
      external_system: @system,
      submitted_by: User.current,
      job_type: params[:job_type],
      input_parameters: params[:input_parameters] || {}
    )

    if @job.save
      # Submit to external system
      begin
        client = @system.client
        result = client.submit_job(@job)
        @job.submit!(result[:job_id])

        respond_to do |format|
          format.html do
            flash[:notice] = 'Job submitted successfully'
            redirect_to issue_path(@issue)
          end
          format.json { render json: job_json(@job), status: :created }
        end
      rescue StandardError => e
        @job.fail!(e.message)
        respond_to do |format|
          format.html do
            flash[:error] = "Job submission failed: #{e.message}"
            redirect_to issue_path(@issue)
          end
          format.json { render json: { error: e.message }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = @job.errors.full_messages.join(', ')
          redirect_to issue_path(@issue)
        end
        format.json { render json: { errors: @job.errors }, status: :unprocessable_entity }
      end
    end
  end

  def cancel
    if @job.cancellable?
      begin
        client = @job.external_system.client
        client.cancel_job(@job.external_job_id) if @job.external_job_id.present?
        @job.cancel!

        respond_to do |format|
          format.html do
            flash[:notice] = 'Job cancelled'
            redirect_to issue_path(@issue)
          end
          format.json { render json: job_json(@job) }
        end
      rescue StandardError => e
        respond_to do |format|
          format.html do
            flash[:error] = "Cancel failed: #{e.message}"
            redirect_to issue_path(@issue)
          end
          format.json { render json: { error: e.message }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = 'Job cannot be cancelled'
          redirect_to issue_path(@issue)
        end
        format.json { render json: { error: 'Job cannot be cancelled' }, status: :unprocessable_entity }
      end
    end
  end

  # Callback endpoint for external systems to update job status
  def callback
    job = LabFlowExternalJob.find_by!(external_job_id: params[:external_job_id])

    case params[:status]
    when 'running'
      job.start!
    when 'completed', 'ok'
      job.complete!(params[:output_data] || {})
    when 'failed', 'error'
      job.fail!(params[:error_message] || 'External job failed')
    end

    render json: { status: 'ok' }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Job not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_job
    @job = LabFlowExternalJob.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def jobs_json(jobs)
    jobs.map { |j| job_json(j) }
  end

  def job_json(job)
    {
      id: job.id,
      external_system: job.external_system.name,
      job_type: job.job_type,
      status: job.status,
      external_job_id: job.external_job_id,
      submitted_by: job.submitted_by.name,
      submitted_at: job.submitted_at&.iso8601,
      started_at: job.started_at&.iso8601,
      completed_at: job.completed_at&.iso8601,
      duration: job.human_duration,
      error_message: job.error_message,
      cancellable: job.cancellable?
    }
  end
end
