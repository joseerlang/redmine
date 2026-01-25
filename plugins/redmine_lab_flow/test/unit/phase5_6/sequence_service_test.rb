# frozen_string_literal: true

require_relative '../../test_helper'

class SequenceServiceTest < ActiveSupport::TestCase
  # Mock sequence object for testing
  class MockSequence
    attr_reader :sequence_data, :circular

    def initialize(seq, circular: false)
      @sequence_data = seq
      @circular = circular
    end

    def clean_sequence
      @sequence_data.gsub(/[^ATGCUatgcu]/, '').upcase
    end

    def circular?
      @circular
    end
  end

  def test_parse_fasta
    skip "SequenceService not available" unless defined?(RedmineLabFlow::SequenceService)

    fasta = <<~FASTA
      >test_sequence description
      ATGCATGCATGC
      ATGCATGC
    FASTA

    result = RedmineLabFlow::SequenceService.parse_fasta(fasta)

    assert result.is_a?(Array)
    assert_equal 1, result.length
    assert_equal 'test_sequence description', result.first[:name]
    assert_equal 'ATGCATGCATGCATGCATGC', result.first[:sequence]
  end

  def test_gc_content
    skip "SequenceService not available" unless defined?(RedmineLabFlow::SequenceService)

    # 50% GC content
    assert_equal 50.0, RedmineLabFlow::SequenceService.gc_content('GGCCATAT')

    # 0% GC content
    assert_equal 0.0, RedmineLabFlow::SequenceService.gc_content('AATTAATT')

    # 100% GC content
    assert_equal 100.0, RedmineLabFlow::SequenceService.gc_content('GGCCGGCC')
  end

  def test_reverse_complement
    skip "SequenceService not available" unless defined?(RedmineLabFlow::SequenceService)

    assert_equal 'GCATGCAT', RedmineLabFlow::SequenceService.reverse_complement('ATGCATGC')
  end

  def test_translate_dna
    skip "SequenceService not available" unless defined?(RedmineLabFlow::SequenceService)

    mock_seq = MockSequence.new('ATGTAA')
    protein = RedmineLabFlow::SequenceService.translate(mock_seq)
    assert_equal 'M*', protein
  end

  def test_find_restriction_sites
    skip "SequenceService not available" unless defined?(RedmineLabFlow::SequenceService)

    # EcoRI site is GAATTC
    mock_seq = MockSequence.new('ATGCGAATTCATGC')
    sites = RedmineLabFlow::SequenceService.find_restriction_sites(mock_seq)

    ecori_site = sites.find { |s| s[:enzyme] == 'EcoRI' }
    assert ecori_site.present?, "Should find EcoRI site"
    assert_equal 4, ecori_site[:position]
  end

  def test_parse_genbank
    skip "SequenceService not available" unless defined?(RedmineLabFlow::SequenceService)

    genbank = <<~GB
      LOCUS       TestSeq                   12 bp    DNA     linear
      DEFINITION  Test sequence for unit testing
      ORIGIN
              1 atgcatgcatgc
      //
    GB

    result = RedmineLabFlow::SequenceService.parse_genbank(genbank)

    assert result.is_a?(Hash)
    assert_equal 'TestSeq', result[:name]
    assert_equal 'ATGCATGCATGC', result[:sequence]
  end
end
