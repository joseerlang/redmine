# frozen_string_literal: true

class LabFlowFairMetadata < ActiveRecord::Base
  belongs_to :issue

  LICENSES = {
    'CC0' => 'Public Domain',
    'CC-BY-4.0' => 'Creative Commons Attribution 4.0',
    'CC-BY-SA-4.0' => 'Creative Commons Attribution-ShareAlike 4.0',
    'CC-BY-NC-4.0' => 'Creative Commons Attribution-NonCommercial 4.0',
    'MIT' => 'MIT License',
    'Apache-2.0' => 'Apache License 2.0',
    'custom' => 'Custom License'
  }.freeze

  ACCESS_RIGHTS = %w[open restricted embargoed closed].freeze

  SCHEMA_ORG_TYPES = %w[Dataset CreativeWork ScholarlyArticle SoftwareSourceCode].freeze

  # Alias for compatibility with views that use access_level
  alias_attribute :access_level, :access_rights

  validates :issue, presence: true, uniqueness: true
  validates :license, inclusion: { in: LICENSES.keys }, allow_blank: true
  validates :access_rights, inclusion: { in: ACCESS_RIGHTS }
  validates :schema_org_type, inclusion: { in: SCHEMA_ORG_TYPES }
  validates :doi, format: { with: /\A10\.\d{4,}\/[^\s]+\z/, message: 'must be a valid DOI' }, allow_blank: true
  validates :orcid_creator, format: { with: /\A\d{4}-\d{4}-\d{4}-\d{3}[\dX]\z/, message: 'must be a valid ORCID' }, allow_blank: true

  serialize :keywords, coder: JSON
  serialize :ontology_mappings, coder: JSON
  serialize :related_identifiers, coder: JSON

  def keywords
    raw = super
    return [] if raw.blank?
    raw.is_a?(Array) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    []
  end

  def keywords=(value)
    super(value.is_a?(Array) ? value.to_json : value)
  end

  def ontology_mappings
    raw = super
    return {} if raw.blank?
    raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def ontology_mappings=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  def related_identifiers
    raw = super
    return [] if raw.blank?
    raw.is_a?(Array) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    []
  end

  def related_identifiers=(value)
    super(value.is_a?(Array) ? value.to_json : value)
  end

  # Repository URL - stored in related_identifiers or as a method
  def repository_url
    read_attribute(:repository_url) || nil
  end

  # Ontology terms associated with this metadata
  def ontology_terms
    LabFlowOntologyTerm.where(fair_metadata_id: id)
  rescue StandardError
    []
  end

  # Check if data is accessible
  def accessible?
    return true if access_rights == 'open'
    return false if access_rights == 'closed'
    return Date.current > embargo_until if access_rights == 'embargoed' && embargo_until.present?

    false
  end

  # Individual FAIR component scores
  def findability_score
    score = 0
    score += 50 if doi.present?
    score += 30 if keywords.any?
    score += 20 if ontology_mappings.any?
    [score, 100].min
  end

  def accessibility_score
    score = 0
    score += 60 if accessible?
    score += 40 if license.present?
    [score, 100].min
  end

  def interoperability_score
    score = 0
    score += 60 if ontology_mappings.any?
    score += 40 if schema_org_type.present?
    [score, 100].min
  end

  def reusability_score
    score = 0
    score += 60 if license.present? && license != 'custom'
    score += 40 if orcid_creator.present?
    [score, 100].min
  end

  # FAIR score calculation (average of all components)
  def fair_score
    (findability_score + accessibility_score + interoperability_score + reusability_score) / 4
  end

  # Generate Schema.org JSON-LD
  def to_schema_org
    {
      '@context' => 'https://schema.org/',
      '@type' => schema_org_type,
      'name' => issue.subject,
      'description' => issue.description,
      'identifier' => doi.present? ? "https://doi.org/#{doi}" : nil,
      'dateCreated' => issue.created_on.iso8601,
      'dateModified' => issue.updated_on.iso8601,
      'creator' => orcid_creator.present? ? { '@type' => 'Person', '@id' => "https://orcid.org/#{orcid_creator}" } : nil,
      'license' => license.present? ? license_url : nil,
      'keywords' => keywords.any? ? keywords.join(', ') : nil
    }.compact
  end

  private

  def license_url
    case license
    when 'CC0' then 'https://creativecommons.org/publicdomain/zero/1.0/'
    when 'CC-BY-4.0' then 'https://creativecommons.org/licenses/by/4.0/'
    when 'CC-BY-SA-4.0' then 'https://creativecommons.org/licenses/by-sa/4.0/'
    when 'CC-BY-NC-4.0' then 'https://creativecommons.org/licenses/by-nc/4.0/'
    when 'MIT' then 'https://opensource.org/licenses/MIT'
    when 'Apache-2.0' then 'https://www.apache.org/licenses/LICENSE-2.0'
    else nil
    end
  end
end
