# frozen_string_literal: true

class LabFlowConsolidatedViewController < ApplicationController
  before_action :find_issue
  before_action :authorize

  def show
    @snapshots = LabFlowPropertySnapshot.for_issue(@issue).recent(20)
    @sequences = @issue.lab_flow_sequences.includes(:annotations)
    @fair_metadata = @issue.lab_flow_fair_metadata
    @external_jobs = LabFlowExternalJob.for_issue(@issue).recent

    # Get molecule data from custom fields
    @molecule_smiles = extract_molecule_smiles

    # Get signatures if available
    @signatures = @issue.lab_flow_electronic_signatures if @issue.respond_to?(:lab_flow_electronic_signatures)

    respond_to do |format|
      format.html
      format.json { render json: consolidated_json }
    end
  end

  def timeline
    @snapshots = LabFlowPropertySnapshot.for_issue(@issue).order(created_at: :asc)

    respond_to do |format|
      format.html { render partial: 'timeline' }
      format.json do
        render json: @snapshots.map { |s|
          {
            id: s.id,
            timestamp: s.created_at.iso8601,
            trigger: s.trigger_event,
            summary: s.change_summary,
            status: s.status_name,
            created_by: s.created_by&.name,
            data: s.snapshot_data
          }
        }
      end
    end
  end

  def compare
    snapshot1_id = params[:snapshot_1]
    snapshot2_id = params[:snapshot_2]

    if snapshot1_id.blank? || snapshot2_id.blank?
      @all_snapshots = LabFlowPropertySnapshot.for_issue(@issue)
      render :select_snapshots
      return
    end

    @snapshot1 = LabFlowPropertySnapshot.find(snapshot1_id)
    @snapshot2 = LabFlowPropertySnapshot.find(snapshot2_id)
    @diff = @snapshot2.diff(@snapshot1)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          snapshot_1: {
            id: @snapshot1.id,
            timestamp: @snapshot1.created_at.iso8601,
            data: @snapshot1.snapshot_data
          },
          snapshot_2: {
            id: @snapshot2.id,
            timestamp: @snapshot2.created_at.iso8601,
            data: @snapshot2.snapshot_data
          },
          diff: @diff
        }
      end
    end
  end

  def export_history
    @snapshots = LabFlowPropertySnapshot.for_issue(@issue).order(created_at: :asc)

    format = params[:export_format] || 'json'

    case format
    when 'json'
      render json: {
        issue: {
          id: @issue.id,
          subject: @issue.subject,
          tracker: @issue.tracker.name,
          project: @issue.project.identifier
        },
        history: @snapshots.map { |s|
          {
            timestamp: s.created_at.iso8601,
            trigger: s.trigger_event,
            data: s.snapshot_data
          }
        }
      }
    when 'csv'
      csv_data = generate_history_csv(@snapshots)
      send_data csv_data, filename: "issue_#{@issue.id}_history.csv", type: 'text/csv'
    else
      render json: { error: 'Unknown format' }, status: :bad_request
    end
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def extract_molecule_smiles
    @issue.custom_field_values.each do |cfv|
      return cfv.value if cfv.custom_field.field_format == 'molecule' && cfv.value.present?
    end
    nil
  end

  def consolidated_json
    {
      issue: {
        id: @issue.id,
        subject: @issue.subject,
        description: @issue.description,
        status: @issue.status.name,
        tracker: @issue.tracker.name,
        created_on: @issue.created_on.iso8601,
        updated_on: @issue.updated_on.iso8601
      },
      custom_fields: @issue.custom_field_values.map { |cfv|
        {
          name: cfv.custom_field.name,
          value: cfv.value,
          format: cfv.custom_field.field_format
        }
      },
      molecule: @molecule_smiles.present? ? {
        smiles: @molecule_smiles,
        render_url: lab_flow_molecules_render_path(smiles: @molecule_smiles)
      } : nil,
      sequences: @sequences.map { |s|
        {
          id: s.id,
          name: s.name,
          type: s.sequence_type,
          length: s.length,
          circular: s.circular,
          gc_content: s.gc_content,
          annotations_count: s.annotations.count
        }
      },
      fair_metadata: @fair_metadata ? {
        doi: @fair_metadata.doi,
        license: @fair_metadata.license,
        fair_score: @fair_metadata.fair_score,
        accessible: @fair_metadata.accessible?
      } : nil,
      external_jobs: @external_jobs.map { |j|
        {
          id: j.id,
          system: j.external_system.name,
          status: j.status,
          submitted_at: j.submitted_at&.iso8601
        }
      },
      snapshots_count: @snapshots.count,
      latest_snapshot: @snapshots.first&.created_at&.iso8601
    }
  end

  def generate_history_csv(snapshots)
    require 'csv'

    # Collect all unique keys from snapshot data
    all_keys = snapshots.flat_map { |s| s.snapshot_data.keys }.uniq

    CSV.generate do |csv|
      csv << ['Timestamp', 'Trigger', 'Created By'] + all_keys

      snapshots.each do |snapshot|
        row = [
          snapshot.created_at.iso8601,
          snapshot.trigger_event,
          snapshot.created_by&.name
        ]

        all_keys.each do |key|
          value = snapshot.snapshot_data[key]
          row << (value.is_a?(Hash) ? value.to_json : value.to_s)
        end

        csv << row
      end
    end
  end
end
