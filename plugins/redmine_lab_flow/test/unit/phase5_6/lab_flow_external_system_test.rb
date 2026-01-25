# frozen_string_literal: true

require_relative '../../test_helper'

class LabFlowExternalSystemTest < ActiveSupport::TestCase
  def test_create_valid_galaxy_system
    skip "LabFlowExternalSystem not available" unless defined?(LabFlowExternalSystem)

    system = LabFlowExternalSystem.new(
      name: 'Test Galaxy',
      system_type: 'galaxy',
      base_url: 'https://usegalaxy.org',
      active: true
    )

    assert system.valid?, "System should be valid: #{system.errors.full_messages.join(', ')}"
    assert system.save
  end

  def test_create_openbis_system
    skip "LabFlowExternalSystem not available" unless defined?(LabFlowExternalSystem)

    system = LabFlowExternalSystem.create!(
      name: 'Test OpenBIS',
      system_type: 'openbis',
      base_url: 'https://openbis.example.com',
      active: true
    )

    assert_equal 'openbis', system.system_type
  end

  def test_validates_system_type
    skip "LabFlowExternalSystem not available" unless defined?(LabFlowExternalSystem)

    system = LabFlowExternalSystem.new(
      name: 'Invalid',
      system_type: 'invalid_type',
      base_url: 'https://example.com'
    )

    assert_not system.valid?
  end

  def test_client_method_returns_correct_client
    skip "LabFlowExternalSystem not available" unless defined?(LabFlowExternalSystem)

    galaxy = LabFlowExternalSystem.create!(
      name: 'Galaxy Test',
      system_type: 'galaxy',
      base_url: 'https://usegalaxy.org',
      active: true
    )

    client = galaxy.client
    assert client.is_a?(RedmineLabFlow::GalaxyClient)
  end

  def test_health_check_method_exists
    skip "LabFlowExternalSystem not available" unless defined?(LabFlowExternalSystem)

    system = LabFlowExternalSystem.create!(
      name: 'Health Check Test',
      system_type: 'custom',
      base_url: 'https://httpbin.org',
      health_check_url: 'https://httpbin.org/status/200',
      active: true
    )

    # Just test that the method exists
    assert system.respond_to?(:check_health!)
  end
end
