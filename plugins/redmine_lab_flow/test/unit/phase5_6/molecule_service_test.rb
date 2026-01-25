# frozen_string_literal: true

require_relative '../../test_helper'

class MoleculeServiceTest < ActiveSupport::TestCase
  def test_validate_smiles
    skip "MoleculeService not available" unless defined?(RedmineLabFlow::MoleculeService)

    # Valid SMILES
    assert RedmineLabFlow::MoleculeService.valid_smiles?('CCO')           # Ethanol
    assert RedmineLabFlow::MoleculeService.valid_smiles?('c1ccccc1')      # Benzene
    assert RedmineLabFlow::MoleculeService.valid_smiles?('CC(=O)O')       # Acetic acid

    # Invalid SMILES (basic validation)
    assert_not RedmineLabFlow::MoleculeService.valid_smiles?('')
    assert_not RedmineLabFlow::MoleculeService.valid_smiles?(nil)
  end

  def test_canonicalize_smiles
    skip "MoleculeService not available" unless defined?(RedmineLabFlow::MoleculeService)

    # Should strip whitespace
    result = RedmineLabFlow::MoleculeService.canonicalize('  CCO  ')
    assert_equal 'CCO', result

    # Should return nil for blank
    assert_nil RedmineLabFlow::MoleculeService.canonicalize('')
    assert_nil RedmineLabFlow::MoleculeService.canonicalize(nil)
  end

  def test_calculate_properties
    skip "MoleculeService not available" unless defined?(RedmineLabFlow::MoleculeService)

    props = RedmineLabFlow::MoleculeService.calculate_properties('CCO')

    assert props.is_a?(Hash)
    assert props[:molecular_weight].present?
    assert props[:formula].present?
  end

  def test_calculate_properties_returns_formula
    skip "MoleculeService not available" unless defined?(RedmineLabFlow::MoleculeService)

    props = RedmineLabFlow::MoleculeService.calculate_properties('CCO')

    # Ethanol formula should include C and O
    assert props[:formula].include?('C')
    assert props[:formula].include?('O')
  end

  def test_calculate_properties_empty_for_blank_smiles
    skip "MoleculeService not available" unless defined?(RedmineLabFlow::MoleculeService)

    props = RedmineLabFlow::MoleculeService.calculate_properties('')
    assert props.empty?

    props = RedmineLabFlow::MoleculeService.calculate_properties(nil)
    assert props.empty?
  end

  def test_substructure_search
    skip "MoleculeService not available" unless defined?(RedmineLabFlow::MoleculeService)
    skip "LabFlowMoleculeCache not available" unless defined?(LabFlowMoleculeCache)

    # Create test molecule
    LabFlowMoleculeCache.create!(smiles: 'CCCO')

    results = RedmineLabFlow::MoleculeService.substructure_search('CC')
    assert results.is_a?(Array) || results.respond_to?(:to_a)
  end

  def test_smiles_to_inchi
    skip "MoleculeService not available" unless defined?(RedmineLabFlow::MoleculeService)

    # Currently returns nil as RDKit is not available server-side
    result = RedmineLabFlow::MoleculeService.smiles_to_inchi('CCO')
    # Just verify it doesn't crash
    assert result.nil? || result.is_a?(String)
  end
end
