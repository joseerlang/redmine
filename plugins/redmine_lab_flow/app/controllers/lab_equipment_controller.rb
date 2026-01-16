# frozen_string_literal: true

class LabEquipmentController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin
  before_action :find_equipment, only: %i[edit update destroy]

  helper :settings

  def index
    redirect_to plugin_settings_path
  end

  def new
    @equipment_item = LabEquipment.new
  end

  def create
    @equipment_item = LabEquipment.new
    @equipment_item.safe_attributes = params[:lab_equipment]

    if @equipment_item.save
      update_equipment_field_values
      flash[:notice] = l(:notice_successful_create)
      redirect_to plugin_settings_path
    else
      render :new
    end
  end

  def edit
  end

  def update
    @equipment_item.safe_attributes = params[:lab_equipment]

    if @equipment_item.save
      update_equipment_field_values
      flash[:notice] = l(:notice_successful_update)
      redirect_to plugin_settings_path
    else
      render :edit
    end
  end

  def destroy
    @equipment_item.destroy
    update_equipment_field_values
    flash[:notice] = l(:notice_successful_delete)
    redirect_to plugin_settings_path
  end

  private

  def plugin_settings_path
    "/settings/plugin/redmine_lab_flow?tab=lab_equipment"
  end

  def find_equipment
    @equipment_item = LabEquipment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def update_equipment_field_values
    field = IssueCustomField.find_by(name: I18n.t(:field_equipment_id))
    return unless field

    field.possible_values = LabEquipment.active.sorted.map(&:display_name)
    field.save
  end
end
