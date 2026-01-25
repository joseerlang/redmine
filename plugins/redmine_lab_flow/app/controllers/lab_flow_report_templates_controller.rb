# frozen_string_literal: true

class LabFlowReportTemplatesController < ApplicationController
  before_action :require_admin
  before_action :find_template, only: [:edit, :update, :destroy]

  def index
    @templates = LabFlowReportTemplate.includes(:tracker).order(:name)
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

  private

  def find_template
    @template = LabFlowReportTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def template_params
    params.require(:lab_flow_report_template).permit(
      :name, :description, :report_type, :tracker_id, :template_content,
      :header_template, :body_template, :footer_template,
      :include_eln_narrative, :include_signatures, :include_attachments,
      :custom_css, :output_format, :active
    )
  end
end
