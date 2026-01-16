# frozen_string_literal: true

class ProcedureTemplatesController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin, except: [:show]
  before_action :find_template, only: %i[show edit update destroy]

  helper :settings

  def index
    redirect_to plugin_settings_path
  end

  def new
    @template = LabFlowProcedureTemplate.new
  end

  def create
    @template = LabFlowProcedureTemplate.new
    @template.safe_attributes = params[:procedure_template]

    if @template.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to plugin_settings_path
    else
      render :new
    end
  end

  def show
    respond_to do |format|
      format.json { render json: { id: @template.id, name: @template.name, content: @template.content } }
    end
  end

  def edit
    # Template is loaded by find_template before_action; view renders the form
  end

  def update
    @template.safe_attributes = params[:procedure_template]

    if @template.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to plugin_settings_path
    else
      render :edit
    end
  end

  def destroy
    @template.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to plugin_settings_path
  end

  private

  def plugin_settings_path
    "/settings/plugin/redmine_lab_flow?tab=procedure_templates"
  end

  def find_template
    @template = LabFlowProcedureTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
