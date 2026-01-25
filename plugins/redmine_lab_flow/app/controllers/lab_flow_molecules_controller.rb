# frozen_string_literal: true

class LabFlowMoleculesController < ApplicationController
  skip_before_action :check_if_login_required, only: [:render_svg]

  def render_svg
    smiles = params[:smiles]

    if smiles.blank?
      render plain: '', status: :bad_request
      return
    end

    # Check cache first
    cache = LabFlowMoleculeCache.for_smiles(smiles)

    if cache&.svg_2d.present?
      render body: cache.svg_2d, content_type: 'image/svg+xml'
    else
      # Return a placeholder - actual SVG rendered client-side by RDKit.js
      render body: placeholder_svg(smiles), content_type: 'image/svg+xml'
    end
  end

  def convert
    smiles = params[:smiles]
    target_format = params[:format] || 'inchi'

    if smiles.blank?
      render json: { error: 'SMILES required' }, status: :bad_request
      return
    end

    result = case target_format
             when 'inchi'
               { inchi: RedmineLabFlow::MoleculeService.smiles_to_inchi(smiles) }
             when 'mol'
               { mol: RedmineLabFlow::MoleculeService.smiles_to_mol(smiles) }
             when 'canonical'
               { canonical_smiles: RedmineLabFlow::MoleculeService.canonicalize(smiles) }
             else
               { error: 'Unknown format' }
             end

    render json: result
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def search
    query_smiles = params[:query_smiles]
    search_type = params[:search_type] || 'substructure'

    if query_smiles.blank?
      render json: { error: 'Query SMILES required' }, status: :bad_request
      return
    end

    results = case search_type
              when 'substructure'
                RedmineLabFlow::MoleculeService.substructure_search(query_smiles)
              when 'similarity'
                threshold = params[:threshold]&.to_f || 0.7
                RedmineLabFlow::MoleculeService.similarity_search(query_smiles, threshold: threshold)
              when 'exact'
                cache = LabFlowMoleculeCache.find_by(smiles: RedmineLabFlow::MoleculeService.canonicalize(query_smiles))
                cache ? [cache] : []
              else
                []
              end

    render json: {
      query: query_smiles,
      search_type: search_type,
      count: results.size,
      results: results.map { |r| molecule_json(r) }
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def editor
    # Render Ketcher molecular editor page
    @return_url = params[:return_url]
    @field_id = params[:field_id]
    @current_smiles = params[:smiles]

    render layout: 'base'
  end

  def properties
    @smiles = params[:smiles]

    if @smiles.blank?
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: 'SMILES required' }
        format.json { render json: { error: 'SMILES required' }, status: :bad_request }
      end
      return
    end

    @cache = LabFlowMoleculeCache.for_smiles(@smiles)
    @cache&.calculate_properties! if @cache && @cache.molecular_weight.nil?

    # Calculate properties from service if cache doesn't have them
    @properties = RedmineLabFlow::MoleculeService.calculate_properties(@smiles)

    respond_to do |format|
      format.html { render layout: 'base' }
      format.json do
        if @cache
          render json: {
            smiles: @cache.smiles,
            inchi: @cache.inchi,
            inchi_key: @cache.inchi_key,
            molecular_formula: @cache.molecular_formula,
            molecular_weight: @cache.molecular_weight,
            log_p: @cache.log_p,
            tpsa: @cache.tpsa,
            hbd: @cache.hbd,
            hba: @cache.hba,
            rotatable_bonds: @cache.rotatable_bonds,
            lipinski_compliant: @cache.lipinski_compliant?
          }
        else
          render json: @properties
        end
      end
    end
  end

  private

  def molecule_json(cache)
    {
      id: cache.id,
      smiles: cache.smiles,
      inchi_key: cache.inchi_key,
      molecular_formula: cache.molecular_formula,
      molecular_weight: cache.molecular_weight&.round(2)
    }
  end

  def placeholder_svg(smiles)
    # Generate a simple placeholder SVG with SMILES text
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="200" height="150" viewBox="0 0 200 150">
        <rect width="200" height="150" fill="#f5f5f5" stroke="#ddd"/>
        <text x="100" y="70" text-anchor="middle" font-family="monospace" font-size="10" fill="#666">
          #{CGI.escapeHTML(smiles.truncate(30))}
        </text>
        <text x="100" y="90" text-anchor="middle" font-family="sans-serif" font-size="8" fill="#999">
          Loading structure...
        </text>
        <g class="molecule-placeholder" data-smiles="#{CGI.escapeHTML(smiles)}"></g>
      </svg>
    SVG
  end
end
