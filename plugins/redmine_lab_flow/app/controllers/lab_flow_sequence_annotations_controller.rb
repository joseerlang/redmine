# frozen_string_literal: true

class LabFlowSequenceAnnotationsController < ApplicationController
  before_action :find_sequence
  before_action :authorize
  before_action :find_annotation, only: [:update, :destroy]

  def create
    @annotation = @sequence.annotations.build(annotation_params)

    if @annotation.save
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_to issue_lab_flow_sequence_path(@issue, @sequence)
        end
        format.json { render json: annotation_json(@annotation), status: :created }
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = @annotation.errors.full_messages.join(', ')
          redirect_to issue_lab_flow_sequence_path(@issue, @sequence)
        end
        format.json { render json: { errors: @annotation.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @annotation.update(annotation_params)
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_to issue_lab_flow_sequence_path(@issue, @sequence)
        end
        format.json { render json: annotation_json(@annotation) }
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = @annotation.errors.full_messages.join(', ')
          redirect_to issue_lab_flow_sequence_path(@issue, @sequence)
        end
        format.json { render json: { errors: @annotation.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @annotation.destroy

    respond_to do |format|
      format.html do
        flash[:notice] = l(:notice_successful_delete)
        redirect_to issue_lab_flow_sequence_path(@issue, @sequence)
      end
      format.json { head :no_content }
    end
  end

  private

  def find_sequence
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
    @sequence = @issue.lab_flow_sequences.find(params[:lab_flow_sequence_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_annotation
    @annotation = @sequence.annotations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def annotation_params
    params.require(:lab_flow_sequence_annotation).permit(
      :name, :annotation_type, :start_position, :end_position,
      :strand, :color, :notes
    )
  end

  def annotation_json(annotation)
    {
      id: annotation.id,
      name: annotation.name,
      type: annotation.annotation_type,
      start: annotation.start_position,
      end: annotation.end_position,
      strand: annotation.strand,
      strand_display: annotation.strand_display,
      color: annotation.color,
      notes: annotation.notes,
      length: annotation.length
    }
  end
end
