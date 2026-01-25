# frozen_string_literal: true

class LabFlowSequencesController < ApplicationController
  before_action :find_issue
  before_action :authorize
  before_action :find_sequence, only: [:show, :edit, :update, :destroy, :export, :restriction_map]

  def index
    @sequences = @issue.lab_flow_sequences.includes(:annotations)

    respond_to do |format|
      format.html
      format.json { render json: sequences_json(@sequences) }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: sequence_json(@sequence, include_annotations: true) }
    end
  end

  def new
    @sequence = @issue.lab_flow_sequences.build
  end

  def create
    @sequence = @issue.lab_flow_sequences.build(sequence_params)

    # Parse uploaded file if present
    if params[:sequence_file].present?
      parse_sequence_file(params[:sequence_file])
    end

    if @sequence.save
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_to issue_path(@issue)
        end
        format.json { render json: sequence_json(@sequence), status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new }
        format.json { render json: { errors: @sequence.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @sequence.update(sequence_params)
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_to issue_path(@issue)
        end
        format.json { render json: sequence_json(@sequence) }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: { errors: @sequence.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @sequence.destroy

    respond_to do |format|
      format.html do
        flash[:notice] = l(:notice_successful_delete)
        redirect_to issue_path(@issue)
      end
      format.json { head :no_content }
    end
  end

  def export
    format = params[:export_format] || 'fasta'

    content = case format
              when 'fasta'
                @sequence.to_fasta
              when 'genbank'
                RedmineLabFlow::SequenceService.to_genbank(@sequence)
              else
                @sequence.sequence_data
              end

    filename = "#{@sequence.name.parameterize}_#{@sequence.id}.#{format == 'genbank' ? 'gb' : format}"

    send_data content, filename: filename, type: 'text/plain', disposition: 'attachment'
  end

  def restriction_map
    enzymes = params[:enzymes]&.split(',') || RedmineLabFlow::SequenceService::COMMON_ENZYMES.keys

    sites = RedmineLabFlow::SequenceService.find_restriction_sites(@sequence, enzymes)

    respond_to do |format|
      format.html do
        @restriction_sites = sites
        render partial: 'restriction_sites'
      end
      format.json { render json: sites }
    end
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_sequence
    @sequence = @issue.lab_flow_sequences.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def sequence_params
    params.require(:lab_flow_sequence).permit(
      :name, :sequence_type, :sequence_data, :format, :circular
    ).tap do |p|
      if params[:lab_flow_sequence][:metadata].present?
        p[:metadata] = JSON.parse(params[:lab_flow_sequence][:metadata])
      end
    rescue JSON::ParserError
      p[:metadata] = {}
    end
  end

  def parse_sequence_file(file)
    content = file.read

    if file.original_filename.end_with?('.fasta', '.fa', '.fna', '.faa')
      @sequence.format = 'fasta'
      @sequence.sequence_data = content

      # Extract name from FASTA header if not provided
      if @sequence.name.blank? && content.start_with?('>')
        header = content.lines.first.strip
        @sequence.name = header[1..].split(/\s/).first
      end
    elsif file.original_filename.end_with?('.gb', '.gbk', '.genbank')
      @sequence.format = 'genbank'
      @sequence.sequence_data = content

      # Parse GenBank format
      parsed = RedmineLabFlow::SequenceService.parse_genbank(content)
      @sequence.name = parsed[:name] if @sequence.name.blank? && parsed[:name].present?
      @sequence.circular = parsed[:circular] if parsed.key?(:circular)
    else
      @sequence.format = 'raw'
      @sequence.sequence_data = content.gsub(/\s/, '')
    end
  end

  def sequences_json(sequences)
    sequences.map { |s| sequence_json(s) }
  end

  def sequence_json(sequence, include_annotations: false)
    json = {
      id: sequence.id,
      name: sequence.name,
      sequence_type: sequence.sequence_type,
      format: sequence.format,
      length: sequence.length,
      circular: sequence.circular,
      gc_content: sequence.gc_content,
      created_at: sequence.created_at.iso8601,
      updated_at: sequence.updated_at.iso8601
    }

    if include_annotations
      json[:sequence_data] = sequence.sequence_data
      json[:annotations] = sequence.annotations.ordered.map { |a| annotation_json(a) }
    end

    json
  end

  def annotation_json(annotation)
    {
      id: annotation.id,
      name: annotation.name,
      type: annotation.annotation_type,
      start: annotation.start_position,
      end: annotation.end_position,
      strand: annotation.strand,
      color: annotation.color,
      notes: annotation.notes
    }
  end
end
