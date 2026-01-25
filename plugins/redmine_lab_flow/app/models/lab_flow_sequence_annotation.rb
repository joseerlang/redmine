# frozen_string_literal: true

class LabFlowSequenceAnnotation < ActiveRecord::Base
  belongs_to :sequence, class_name: 'LabFlowSequence'

  ANNOTATION_TYPES = %w[
    gene
    cds
    promoter
    terminator
    primer
    restriction_site
    origin
    marker
    tag
    regulatory
    misc_feature
  ].freeze

  STRANDS = { forward: 1, reverse: -1, none: 0 }.freeze

  DEFAULT_COLORS = {
    'gene' => '#4CAF50',
    'cds' => '#2196F3',
    'promoter' => '#FF9800',
    'terminator' => '#F44336',
    'primer' => '#9C27B0',
    'restriction_site' => '#E91E63',
    'origin' => '#00BCD4',
    'marker' => '#FFEB3B',
    'tag' => '#795548',
    'regulatory' => '#607D8B',
    'misc_feature' => '#9E9E9E'
  }.freeze

  validates :sequence, :name, :annotation_type, presence: true
  validates :annotation_type, inclusion: { in: ANNOTATION_TYPES }
  validates :start_position, :end_position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :strand, inclusion: { in: STRANDS.values }

  validate :positions_within_sequence
  validate :start_before_end_for_linear

  scope :by_type, ->(type) { where(annotation_type: type) }
  scope :forward_strand, -> { where(strand: 1) }
  scope :reverse_strand, -> { where(strand: -1) }
  scope :in_range, ->(start_pos, end_pos) { where('start_position <= ? AND end_position >= ?', end_pos, start_pos) }
  scope :ordered, -> { order(:start_position) }

  before_validation :set_default_color

  # Length of the annotated region
  def length
    if sequence&.circular? && end_position < start_position
      # Wraps around origin
      sequence.length - start_position + end_position
    else
      end_position - start_position + 1
    end
  end

  # Extract the sequence for this annotation
  def annotated_sequence
    return nil unless sequence

    seq = sequence.clean_sequence

    if sequence.circular? && end_position < start_position
      # Wraps around origin
      seq[start_position..] + seq[0..end_position]
    else
      seq[start_position..end_position]
    end
  end

  # Get strand as symbol
  def strand_symbol
    case strand
    when 1 then :forward
    when -1 then :reverse
    else :none
    end
  end

  # Display strand
  def strand_display
    case strand
    when 1 then '+'
    when -1 then '-'
    else '.'
    end
  end

  # Position range as string
  def position_range
    "#{start_position + 1}..#{end_position + 1}" # Convert to 1-based for display
  end

  # SeqViz-compatible format
  def to_seqviz
    {
      name: name,
      start: start_position,
      end: end_position,
      direction: strand,
      color: color || DEFAULT_COLORS[annotation_type]
    }
  end

  # GenBank feature format
  def to_genbank_feature
    strand_prefix = strand == -1 ? 'complement(' : ''
    strand_suffix = strand == -1 ? ')' : ''

    location = if sequence&.circular? && end_position < start_position
                 "join(#{start_position + 1}..#{sequence.length},1..#{end_position + 1})"
               else
                 "#{start_position + 1}..#{end_position + 1}"
               end

    <<~GENBANK
         #{annotation_type.ljust(15)} #{strand_prefix}#{location}#{strand_suffix}
                           /label="#{name}"
                           #{notes.present? ? "/note=\"#{notes}\"" : ''}
    GENBANK
  end

  private

  def positions_within_sequence
    return unless sequence

    max_pos = sequence.length - 1
    if start_position > max_pos
      errors.add(:start_position, "must be within sequence length (max: #{max_pos})")
    end
    if end_position > max_pos && !sequence.circular?
      errors.add(:end_position, "must be within sequence length (max: #{max_pos})")
    end
  end

  def start_before_end_for_linear
    return if sequence&.circular?

    if start_position.present? && end_position.present? && start_position > end_position
      errors.add(:end_position, 'must be greater than or equal to start position for linear sequences')
    end
  end

  def set_default_color
    self.color ||= DEFAULT_COLORS[annotation_type]
  end
end
