# frozen_string_literal: true

require_relative '../../test_helper'

class LabFlowSequenceTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :issue_statuses, :issues

  def setup
    @issue = Issue.first
  end

  def test_create_valid_dna_sequence
    skip "LabFlowSequence not available" unless defined?(LabFlowSequence)

    sequence = LabFlowSequence.new(
      issue: @issue,
      name: 'Test DNA Sequence',
      sequence_type: 'dna',
      sequence_data: 'ATGCATGCATGC',
      circular: false
    )

    assert sequence.valid?, "Sequence should be valid: #{sequence.errors.full_messages.join(', ')}"
    assert sequence.save
    assert_equal 12, sequence.length
  end

  def test_create_plasmid_sequence
    skip "LabFlowSequence not available" unless defined?(LabFlowSequence)

    sequence = LabFlowSequence.create!(
      issue: @issue,
      name: 'Test Plasmid',
      sequence_type: 'plasmid',
      sequence_data: 'ATGCATGCATGCATGCATGC',
      circular: true
    )

    assert sequence.circular?
    assert_equal 'plasmid', sequence.sequence_type
  end

  def test_validates_sequence_type
    skip "LabFlowSequence not available" unless defined?(LabFlowSequence)

    sequence = LabFlowSequence.new(
      issue: @issue,
      name: 'Invalid Type',
      sequence_type: 'invalid',
      sequence_data: 'ATGC'
    )

    assert_not sequence.valid?
  end

  def test_gc_content_calculation
    skip "LabFlowSequence not available" unless defined?(LabFlowSequence)

    sequence = LabFlowSequence.create!(
      issue: @issue,
      name: 'GC Test',
      sequence_type: 'dna',
      sequence_data: 'GGCCATAT', # 4 GC out of 8 = 50%
      circular: false
    )

    assert_equal 50.0, sequence.gc_content
  end

  def test_clean_sequence
    skip "LabFlowSequence not available" unless defined?(LabFlowSequence)

    sequence = LabFlowSequence.create!(
      issue: @issue,
      name: 'Clean Test',
      sequence_type: 'dna',
      sequence_data: "ATGC\nATGC\r\n  ATGC  ",
      circular: false
    )

    assert_equal 'ATGCATGCATGC', sequence.clean_sequence
  end
end
