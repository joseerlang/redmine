# frozen_string_literal: true

class LabFlowOntologyTerm < ActiveRecord::Base
  belongs_to :parent_term, class_name: 'LabFlowOntologyTerm', optional: true
  belongs_to :custom_field, optional: true

  has_many :child_terms, class_name: 'LabFlowOntologyTerm', foreign_key: 'parent_term_id', dependent: :nullify

  ONTOLOGIES = {
    'OBI' => 'Ontology for Biomedical Investigations',
    'CHEBI' => 'Chemical Entities of Biological Interest',
    'NCIT' => 'NCI Thesaurus',
    'EFO' => 'Experimental Factor Ontology',
    'GO' => 'Gene Ontology',
    'SO' => 'Sequence Ontology',
    'UO' => 'Units of Measurement Ontology',
    'PATO' => 'Phenotype And Trait Ontology',
    'BAO' => 'BioAssay Ontology'
  }.freeze

  validates :ontology, presence: true, inclusion: { in: ONTOLOGIES.keys }
  validates :term_id, presence: true
  validates :label, presence: true
  validates :ontology, uniqueness: { scope: :term_id }

  scope :by_ontology, ->(ont) { where(ontology: ont) }
  scope :search, ->(query) { where('label ILIKE ? OR term_id ILIKE ?', "%#{query}%", "%#{query}%") }
  scope :top_level, -> { where(parent_term: nil) }

  # Full term identifier (e.g., OBI:0000070)
  def full_id
    "#{ontology}:#{term_id}"
  end

  # OLS (Ontology Lookup Service) URL
  def ols_url
    return iri if iri.present?

    encoded_id = CGI.escape(full_id)
    "https://www.ebi.ac.uk/ols/ontologies/#{ontology.downcase}/terms?iri=#{encoded_id}"
  end

  # Get all ancestors
  def ancestors
    result = []
    current = parent_term
    while current
      result << current
      current = current.parent_term
    end
    result
  end

  # Get full path as string
  def full_path
    (ancestors.reverse.map(&:label) + [label]).join(' > ')
  end

  # Class method to search OLS API
  def self.search_ols(query, ontology: nil, limit: 20)
    return [] if query.blank?

    base_url = 'https://www.ebi.ac.uk/ols/api/search'
    params = {
      q: query,
      rows: limit,
      exact: false
    }
    params[:ontology] = ontology.downcase if ontology.present?

    uri = URI(base_url)
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    return [] unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    (data.dig('response', 'docs') || []).map do |doc|
      {
        ontology: doc['ontology_name']&.upcase,
        term_id: doc['obo_id']&.split(':')&.last || doc['short_form'],
        label: doc['label'],
        definition: doc['description']&.first,
        iri: doc['iri']
      }
    end
  rescue StandardError => e
    Rails.logger.error "OLS search error: #{e.message}"
    []
  end

  # Import term from OLS search result
  def self.import_from_ols(result)
    return nil unless result[:ontology].present? && result[:term_id].present?

    find_or_create_by(ontology: result[:ontology], term_id: result[:term_id]) do |term|
      term.label = result[:label]
      term.definition = result[:definition]
      term.iri = result[:iri]
    end
  end
end
