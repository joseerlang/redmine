# frozen_string_literal: true

class LabFlowReportsController < ApplicationController
  before_action :require_admin, only: [:new, :create, :edit, :update, :destroy]
  before_action :find_project, only: [:generate, :history, :download]
  before_action :find_template, only: [:edit, :update, :destroy]

  def index
    @templates = LabFlowReportTemplate.active.includes(:tracker)
  end

  def new
    @template = LabFlowReportTemplate.new
  end

  def create
    @template = LabFlowReportTemplate.new(template_params)

    if @template.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to lab_flow_report_templates_path
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to lab_flow_report_templates_path
    else
      render :edit
    end
  end

  def destroy
    @template.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to lab_flow_report_templates_path
  end

  def generate
    @issue = Issue.find(params[:issue_id]) if params[:issue_id].present?
    @template = LabFlowReportTemplate.find(params[:template_id])
    @format = params[:format_type] || 'pdf'

    report = LabFlowGeneratedReport.create!(
      report_template: @template,
      issue: @issue,
      project: @project,
      generated_by: User.current,
      format: @format,
      status: 'pending',
      parameters: {
        issue_id: @issue&.id,
        generated_at: Time.current.iso8601
      }
    )

    # Generate report synchronously (could be moved to background job)
    begin
      generator = RedmineLabFlow::ReportGenerator.new(@template, @issue, @project)
      file_path = generator.generate(@format)

      report.complete!(file_path, File.size(generator.full_path(file_path)))

      redirect_to lab_flow_report_download_path(@project, report)
    rescue StandardError => e
      report.fail!(e.message)
      flash[:error] = "Report generation failed: #{e.message}"
      redirect_back fallback_location: project_path(@project)
    end
  end

  def history
    @report_count = LabFlowGeneratedReport.where(project: @project).count
    @report_pages = Redmine::Pagination::Paginator.new(@report_count, 25, params[:page])
    @reports = LabFlowGeneratedReport.where(project: @project)
                                     .includes(:report_template, :generated_by, :issue)
                                     .order(created_at: :desc)
                                     .limit(@report_pages.per_page)
                                     .offset(@report_pages.offset)
  end

  def download
    @report = LabFlowGeneratedReport.find(params[:id])

    unless @report.downloadable?
      flash[:error] = 'Report file not available'
      redirect_back fallback_location: project_path(@project)
      return
    end

    send_file @report.full_file_path,
              filename: "report_#{@report.id}.#{@report.format}",
              type: content_type_for(@report.format),
              disposition: 'attachment'
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_template
    @template = LabFlowReportTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def template_params
    params.require(:lab_flow_report_template).permit(
      :name, :description, :report_type, :tracker_id,
      :template_content, :include_eln_narrative, :include_signatures,
      :active, fields_to_include: []
    )
  end

  def content_type_for(format)
    case format
    when 'pdf' then 'application/pdf'
    when 'xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'json' then 'application/json'
    when 'html' then 'text/html'
    else 'application/octet-stream'
    end
  end
end
