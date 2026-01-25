# frozen_string_literal: true

class LabFlowFairController < ApplicationController
  before_action :find_issue
  before_action :authorize
  before_action :find_or_build_metadata, only: [:show, :update]

  def show
    respond_to do |format|
      format.html
      format.json { render json: metadata_json(@metadata) }
    end
  end

  def update
    if @metadata.update(metadata_params)
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_to issue_path(@issue)
        end
        format.json { render json: metadata_json(@metadata) }
      end
    else
      respond_to do |format|
        format.html { render :show }
        format.json { render json: { errors: @metadata.errors }, status: :unprocessable_entity }
      end
    end
  end

  def export
    @metadata = @issue.lab_flow_fair_metadata || LabFlowFairMetadata.new(issue: @issue)
    format = params[:export_format] || 'schema_org'

    exporter = RedmineLabFlow::FairExporter.new(@issue, @metadata)

    case format
    when 'schema_org'
      render json: exporter.to_schema_org
    when 'datacite'
      render xml: exporter.to_datacite_xml
    when 'ro_crate'
      render json: exporter.to_ro_crate
    when 'isa_tab'
      send_data exporter.to_isa_tab, filename: "#{@issue.id}_isa.txt", type: 'text/plain'
    else
      render json: { error: 'Unknown format' }, status: :bad_request
    end
  end

  def mint_doi
    # DOI minting is disabled by default
    unless Setting.plugin_redmine_lab_flow['enable_doi_minting'] == '1'
      respond_to do |format|
        format.html do
          flash[:error] = 'DOI minting is not enabled'
          redirect_to issue_path(@issue)
        end
        format.json { render json: { error: 'DOI minting disabled' }, status: :forbidden }
      end
      return
    end

    @metadata = @issue.lab_flow_fair_metadata || LabFlowFairMetadata.create!(issue: @issue)

    begin
      minter = RedmineLabFlow::DoiMinter.new
      doi = minter.mint(@issue, @metadata)
      @metadata.update!(doi: doi)

      respond_to do |format|
        format.html do
          flash[:notice] = "DOI minted: #{doi}"
          redirect_to issue_path(@issue)
        end
        format.json { render json: { doi: doi } }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html do
          flash[:error] = "DOI minting failed: #{e.message}"
          redirect_to issue_path(@issue)
        end
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def ontology_search
    query = params[:q]
    ontology = params[:ontology]

    if query.blank?
      render json: []
      return
    end

    results = LabFlowOntologyTerm.search_ols(query, ontology: ontology, limit: 20)

    render json: results.map { |r|
      {
        id: "#{r[:ontology]}:#{r[:term_id]}",
        text: r[:label],
        ontology: r[:ontology],
        term_id: r[:term_id],
        definition: r[:definition],
        iri: r[:iri]
      }
    }
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_or_build_metadata
    @metadata = @issue.lab_flow_fair_metadata || @issue.build_lab_flow_fair_metadata
  end

  def metadata_params
    params.require(:lab_flow_fair_metadata).permit(
      :doi, :orcid_creator, :license, :schema_org_type,
      :access_rights, :embargo_until, :funding_reference,
      keywords: [], related_identifiers: []
    ).tap do |p|
      # Handle ontology_mappings as JSON
      if params[:lab_flow_fair_metadata][:ontology_mappings].present?
        p[:ontology_mappings] = JSON.parse(params[:lab_flow_fair_metadata][:ontology_mappings])
      end
    rescue JSON::ParserError
      p[:ontology_mappings] = {}
    end
  end

  def metadata_json(metadata)
    {
      doi: metadata.doi,
      orcid_creator: metadata.orcid_creator,
      license: metadata.license,
      license_name: LabFlowFairMetadata::LICENSES[metadata.license],
      keywords: metadata.keywords,
      ontology_mappings: metadata.ontology_mappings,
      schema_org_type: metadata.schema_org_type,
      access_rights: metadata.access_rights,
      embargo_until: metadata.embargo_until&.iso8601,
      funding_reference: metadata.funding_reference,
      related_identifiers: metadata.related_identifiers,
      fair_score: metadata.fair_score,
      accessible: metadata.accessible?
    }
  end
end
