# frozen_string_literal: true

class LabReagentsController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin
  before_action :find_reagent, only: %i[edit update destroy]

  def index
    @reagents = LabReagent.sorted
    @expired_count = LabReagent.expired.count
    @expiring_soon_count = LabReagent.expiring_soon.count
  end

  def new
    @reagent = LabReagent.new
  end

  def create
    @reagent = LabReagent.new
    @reagent.safe_attributes = params[:lab_reagent]

    if @reagent.save
      update_lot_number_field_values
      flash[:notice] = l(:notice_successful_create)
      redirect_to lab_reagents_path
    else
      render :new
    end
  end

  def edit
  end

  def update
    @reagent.safe_attributes = params[:lab_reagent]

    if @reagent.save
      update_lot_number_field_values
      flash[:notice] = l(:notice_successful_update)
      redirect_to lab_reagents_path
    else
      render :edit
    end
  end

  def destroy
    @reagent.destroy
    update_lot_number_field_values
    flash[:notice] = l(:notice_successful_delete)
    redirect_to lab_reagents_path
  end

  private

  def find_reagent
    @reagent = LabReagent.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def update_lot_number_field_values
    field = IssueCustomField.find_by(name: I18n.t(:field_lot_number))
    return unless field

    field.possible_values = LabReagent.active.sorted.map(&:display_name)
    field.save
  end
end
