# frozen_string_literal: true

class LabFlowSequence < ActiveRecord::Base
  belongs_to :issue

  has_many :annotations, class_name: 'LabFlowSequenceAnnotation', foreign_key: 'sequence_id', dependent: :destroy
  has_many :property_snapshots, class_name: 'LabFlowPropertySnapshot', foreign_key: 'sequence_id', dependent: :nullify

  SEQUENCE_TYPES = %w[dna rna protein plasmid].freeze
  FORMATS = %w[raw fasta genbank].freeze

  validates :issue, :name, :sequence_type, :sequence_data, presence: true
  validates :sequence_type, inclusion: { in: SEQUENCE_TYPES }
  validates :format, inclusion: { in: FORMATS }

  before_save :calculate_length
  before_save :validate_sequence_data

  scope :by_type, ->(type) { where(sequence_type: type) }
  scope :circular, -> { where(circular: true) }
  scope :linear, -> { where(circular: false) }

  serialize :metadata, coder: JSON

  def metadata
    raw = super
    return {} if raw.blank?
    raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def metadata=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  # Get clean sequence (no whitespace or headers)
  def clean_sequence
    case format
    when 'fasta'
      sequence_data.lines.reject { |l| l.start_with?('>') }.join.gsub(/\s/, '')
    when 'genbank'
      # Extract ORIGIN section
      if sequence_data =~ /ORIGIN\s+(.*?)\/\//m
        $1.gsub(/[\s\d]/, '')
      else
        sequence_data.gsub(/\s/, '')
      end
    else
      sequence_data.gsub(/\s/, '')
    end
  end

  # GC content for DNA/RNA
  def gc_content
    return nil unless %w[dna rna plasmid].include?(sequence_type)

    seq = clean_sequence.upcase
    return 0 if seq.empty?

    gc_count = seq.count('GC')
    (gc_count.to_f / seq.length * 100).round(2)
  end

  # Complement (DNA only)
  def complement
    return nil unless %w[dna plasmid].include?(sequence_type)

    complement_map = { 'A' => 'T', 'T' => 'A', 'G' => 'C', 'C' => 'G',
                       'a' => 't', 't' => 'a', 'g' => 'c', 'c' => 'g' }
    clean_sequence.chars.map { |c| complement_map[c] || c }.join
  end

  # Reverse complement (DNA only)
  def reverse_complement
    complement&.reverse
  end

  # Translate to protein (DNA/RNA only)
  def translate(frame: 1)
    return nil unless %w[dna rna plasmid].include?(sequence_type)

    seq = clean_sequence.upcase
    seq = seq.gsub('U', 'T') if sequence_type == 'rna'

    # Adjust for reading frame (1, 2, or 3)
    seq = seq[(frame - 1)..]

    codon_table = RedmineLabFlow::SequenceService::CODON_TABLE

    codons = seq.scan(/.{3}/)
    codons.map { |codon| codon_table[codon] || 'X' }.join
  end

  # Export to FASTA format
  def to_fasta
    header = ">#{name}"
    header += " [#{sequence_type}]" if sequence_type.present?
    header += " circular" if circular?

    seq = clean_sequence.scan(/.{1,60}/).join("\n")
    "#{header}\n#{seq}"
  end

  # Annotation types present
  def annotation_types
    annotations.distinct.pluck(:annotation_type)
  end

  private

  def calculate_length
    self.length = clean_sequence.length
  end

  def validate_sequence_data
    seq = clean_sequence.upcase

    valid_chars = case sequence_type
                  when 'dna', 'plasmid'
                    /\A[ATGCNRYKMSWBDHV]+\z/i
                  when 'rna'
                    /\A[AUGCNRYKMSWBDHV]+\z/i
                  when 'protein'
                    /\A[ACDEFGHIKLMNPQRSTVWY*]+\z/i
                  else
                    /\A.+\z/
                  end

    unless seq.match?(valid_chars)
      errors.add(:sequence_data, "contains invalid characters for #{sequence_type}")
    end
  end
end
