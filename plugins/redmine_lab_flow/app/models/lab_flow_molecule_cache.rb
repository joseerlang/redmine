# frozen_string_literal: true

class LabFlowMoleculeCache < ActiveRecord::Base
  validates :smiles, presence: true, uniqueness: true

  serialize :properties, coder: JSON

  def properties
    raw = super
    return {} if raw.blank?
    raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def properties=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  # Find or create a cache entry for a SMILES string
  def self.for_smiles(smiles)
    return nil if smiles.blank?

    canonical = RedmineLabFlow::MoleculeService.canonicalize(smiles) rescue smiles
    find_or_create_by(smiles: canonical)
  end

  # Get SVG rendering (cached or generate)
  def svg
    return svg_2d if svg_2d.present?

    generated_svg = RedmineLabFlow::MoleculeService.render_svg(smiles)
    update!(svg_2d: generated_svg) if generated_svg.present?
    generated_svg
  rescue StandardError => e
    Rails.logger.error "SVG generation failed for #{smiles}: #{e.message}"
    nil
  end

  # Calculate and cache properties
  def calculate_properties!
    props = RedmineLabFlow::MoleculeService.calculate_properties(smiles)
    update!(
      molecular_formula: props[:formula],
      molecular_weight: props[:molecular_weight],
      inchi: props[:inchi],
      inchi_key: props[:inchi_key],
      properties: props
    )
  rescue StandardError => e
    Rails.logger.error "Property calculation failed for #{smiles}: #{e.message}"
  end

  # Common molecular properties
  def log_p
    properties['logP'] || properties['LogP']
  end

  def tpsa
    properties['TPSA'] || properties['tpsa']
  end

  def hbd
    properties['HBD'] || properties['numHBD']
  end

  def hba
    properties['HBA'] || properties['numHBA']
  end

  def rotatable_bonds
    properties['numRotatableBonds'] || properties['rotatable_bonds']
  end

  # Lipinski Rule of 5 compliance
  def lipinski_compliant?
    return nil unless molecular_weight && log_p && hbd && hba

    molecular_weight <= 500 &&
      log_p.to_f <= 5 &&
      hbd.to_i <= 5 &&
      hba.to_i <= 10
  end

  # PubChem URL if available
  def pubchem_url
    return nil unless inchi_key.present?

    "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/inchikey/#{inchi_key}/cids/JSON"
  end
end
