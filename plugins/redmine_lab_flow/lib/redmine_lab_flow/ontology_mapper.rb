# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module RedmineLabFlow
  class OntologyMapper
    # Ontology Lookup Service (OLS) API base URL
    OLS_API_URL = 'https://www.ebi.ac.uk/ols/api'

    # Common ontologies for laboratory science
    SUPPORTED_ONTOLOGIES = %w[
      OBI    # Ontology for Biomedical Investigations
      CHEBI  # Chemical Entities of Biological Interest
      NCIT   # NCI Thesaurus
      EFO    # Experimental Factor Ontology
      UO     # Units of Measurement Ontology
      PATO   # Phenotype And Trait Ontology
      GO     # Gene Ontology
      SO     # Sequence Ontology
      CLO    # Cell Line Ontology
      BAO    # BioAssay Ontology
    ].freeze

    class << self
      # Search for terms across all supported ontologies
      def search(query, options = {})
        ontology = options[:ontology]
        exact = options[:exact] || false
        rows = options[:limit] || 20

        params = {
          q: query,
          rows: rows,
          exact: exact
        }
        params[:ontology] = ontology.downcase if ontology.present?

        response = api_get('/search', params)
        return [] unless response && response['response']

        response['response']['docs'].map do |doc|
          {
            iri: doc['iri'],
            label: doc['label'],
            ontology: doc['ontology_name']&.upcase,
            term_id: extract_term_id(doc['iri']),
            description: doc['description']&.first,
            synonyms: doc['synonyms'] || [],
            is_defining_ontology: doc['is_defining_ontology']
          }
        end
      end

      # Get a specific term by IRI
      def get_term(iri)
        encoded_iri = URI.encode_www_form_component(URI.encode_www_form_component(iri))
        response = api_get("/terms/#{encoded_iri}")
        return nil unless response

        {
          iri: response['iri'],
          label: response['label'],
          ontology: response['ontology_name']&.upcase,
          term_id: extract_term_id(response['iri']),
          description: response['description']&.first,
          synonyms: response['synonyms'] || [],
          is_root: response['is_root'],
          has_children: response['has_children']
        }
      end

      # Get children of a term
      def get_children(iri, options = {})
        encoded_iri = URI.encode_www_form_component(URI.encode_www_form_component(iri))
        response = api_get("/terms/#{encoded_iri}/children", { size: options[:limit] || 50 })
        return [] unless response && response['_embedded']

        response['_embedded']['terms'].map do |term|
          {
            iri: term['iri'],
            label: term['label'],
            term_id: extract_term_id(term['iri']),
            has_children: term['has_children']
          }
        end
      end

      # Get ancestors of a term
      def get_ancestors(iri)
        encoded_iri = URI.encode_www_form_component(URI.encode_www_form_component(iri))
        response = api_get("/terms/#{encoded_iri}/ancestors")
        return [] unless response && response['_embedded']

        response['_embedded']['terms'].map do |term|
          {
            iri: term['iri'],
            label: term['label'],
            term_id: extract_term_id(term['iri'])
          }
        end
      end

      # Suggest terms (autocomplete)
      def suggest(query, options = {})
        ontology = options[:ontology]
        rows = options[:limit] || 10

        params = { q: query, rows: rows }
        params[:ontology] = ontology.downcase if ontology.present?

        response = api_get('/suggest', params)
        return [] unless response && response['response']

        response['response']['docs'].map do |doc|
          {
            label: doc['autosuggest'],
            ontology: doc['ontology_name']&.upcase
          }
        end
      end

      # Cache a term locally in the database
      def cache_term(term_data)
        return nil unless term_data[:iri] && term_data[:label]

        LabFlowOntologyTerm.find_or_create_by!(
          ontology: term_data[:ontology],
          term_id: term_data[:term_id]
        ) do |term|
          term.label = term_data[:label]
          term.iri = term_data[:iri]
          term.definition = term_data[:description]
        end
      end

      # Search local cached terms
      def search_cached(query, options = {})
        scope = LabFlowOntologyTerm.where('label ILIKE ?', "%#{query}%")
        scope = scope.where(ontology: options[:ontology].upcase) if options[:ontology]
        scope.limit(options[:limit] || 20)
      end

      # Map a custom field value to an ontology term
      def map_custom_field(custom_field, value)
        # Try to find an existing mapping
        existing = LabFlowOntologyTerm.where(custom_field_id: custom_field.id)
                                       .where('label ILIKE ?', value)
                                       .first
        return existing if existing

        # Search for a match in OLS
        results = search(value, limit: 5)
        return nil if results.empty?

        # Cache the best match
        best_match = results.first
        term = cache_term(best_match)
        term.update(custom_field_id: custom_field.id) if term
        term
      end

      private

      def api_get(endpoint, params = {})
        uri = URI("#{OLS_API_URL}#{endpoint}")
        uri.query = URI.encode_www_form(params) if params.any?

        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPSuccess)
          JSON.parse(response.body)
        else
          Rails.logger.warn("OLS API error: #{response.code} - #{response.body}")
          nil
        end
      rescue StandardError => e
        Rails.logger.error("OLS API request failed: #{e.message}")
        nil
      end

      def extract_term_id(iri)
        return nil unless iri

        # Extract term ID from IRI (e.g., http://purl.obolibrary.org/obo/OBI_0000070 -> OBI:0000070)
        if iri.include?('/obo/')
          iri.split('/').last.gsub('_', ':')
        else
          iri.split('/').last
        end
      end
    end
  end
end
