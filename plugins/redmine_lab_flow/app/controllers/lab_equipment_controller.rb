# frozen_string_literal: true

class LabEquipmentController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin
  before_action :find_equipment, only: %i[edit update destroy]

  def index
    @equipment = LabEquipment.sorted
    @calibration_overdue_count = LabEquipment.calibration_overdue.count
    @calibration_due_soon_count = LabEquipment.calibration_due_soon.count
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
      redirect_to lab_equipment_index_path
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
      redirect_to lab_equipment_index_path
    else
      render :edit
    end
  end

  def destroy
    @equipment_item.destroy
    update_equipment_field_values
    flash[:notice] = l(:notice_successful_delete)
    redirect_to lab_equipment_index_path
  end

  private

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
