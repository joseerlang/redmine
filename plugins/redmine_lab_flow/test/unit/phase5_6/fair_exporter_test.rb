# frozen_string_literal: true

require_relative '../../test_helper'

class FairExporterTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :issue_statuses, :issues

  def setup
    @issue = Issue.first
    @metadata = nil
    if defined?(LabFlowFairMetadata)
      @metadata = LabFlowFairMetadata.find_or_create_by!(issue: @issue) do |m|
        m.license = 'CC-BY-4.0'
      end
    end
  end

  def test_export_schema_org
    skip "FairExporter not available" unless defined?(RedmineLabFlow::FairExporter)

    exporter = RedmineLabFlow::FairExporter.new(@issue, @metadata)
    result = exporter.to_schema_org

    assert result.is_a?(Hash)
    assert result['@type'].present?
    assert result['name'].present?
  end

  def test_export_datacite
    skip "FairExporter not available" unless defined?(RedmineLabFlow::FairExporter)

    exporter = RedmineLabFlow::FairExporter.new(@issue, @metadata)
    result = exporter.to_datacite_xml

    assert result.is_a?(String)
    assert result.include?('datacite') || result.include?('resource')
  end

  def test_export_ro_crate
    skip "FairExporter not available" unless defined?(RedmineLabFlow::FairExporter)

    exporter = RedmineLabFlow::FairExporter.new(@issue, @metadata)
    result = exporter.to_ro_crate

    assert result.is_a?(Hash)
    assert_equal 'https://w3id.org/ro/crate/1.1/context', result['@context']
  end

  def test_export_with_fair_metadata
    skip "FairExporter not available" unless defined?(RedmineLabFlow::FairExporter)
    skip "LabFlowFairMetadata not available" unless defined?(LabFlowFairMetadata)

    metadata = LabFlowFairMetadata.find_by(issue: @issue)
    metadata ||= LabFlowFairMetadata.create!(
      issue: @issue,
      doi: '10.1234/test.123',
      license: 'CC-BY-4.0',
      keywords: ['test', 'sample']
    )

    exporter = RedmineLabFlow::FairExporter.new(@issue, metadata)
    result = exporter.to_schema_org

    assert result.is_a?(Hash)
    assert result['name'].present?
  end
end
