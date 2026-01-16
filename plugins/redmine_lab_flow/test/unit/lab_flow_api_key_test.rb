# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class LabFlowApiKeyTest < ActiveSupport::TestCase
  fixtures :users, :projects

  def setup
    @user = User.find(1) # admin
    @project = Project.find(1)
  end

  test 'should create api key with valid attributes' do
    api_key = LabFlowApiKey.new(
      project: @project,
      created_by: @user,
      description: 'Test API Key'
    )
    assert api_key.valid?
    assert api_key.save
    assert_not_nil api_key.api_key
    assert_equal 64, api_key.api_key.length # hex(32) = 64 chars
  end

  test 'should require project' do
    api_key = LabFlowApiKey.new(
      created_by: @user,
      description: 'Test API Key'
    )
    assert_not api_key.valid?
    assert api_key.errors[:project_id].present?
  end

  test 'should require created_by' do
    api_key = LabFlowApiKey.new(
      project: @project,
      description: 'Test API Key'
    )
    assert_not api_key.valid?
    assert api_key.errors[:created_by_id].present?
  end

  test 'should auto-generate api_key' do
    api_key = LabFlowApiKey.create!(
      project: @project,
      created_by: @user
    )
    assert_not_nil api_key.api_key
  end

  test 'should enforce unique api_key' do
    key1 = LabFlowApiKey.create!(
      project: @project,
      created_by: @user
    )

    key2 = LabFlowApiKey.new(
      project: @project,
      created_by: @user,
      api_key: key1.api_key
    )
    assert_not key2.valid?
    assert key2.errors[:api_key].present?
  end

  test 'should default to active' do
    api_key = LabFlowApiKey.create!(
      project: @project,
      created_by: @user
    )
    assert api_key.active
  end

  test 'should find and touch api key' do
    api_key = LabFlowApiKey.create!(
      project: @project,
      created_by: @user
    )
    assert_nil api_key.last_used_at

    found = LabFlowApiKey.find_and_touch(api_key.api_key)
    assert_equal api_key, found
    assert_not_nil found.reload.last_used_at
  end

  test 'should not find inactive api key' do
    api_key = LabFlowApiKey.create!(
      project: @project,
      created_by: @user,
      active: false
    )

    found = LabFlowApiKey.find_and_touch(api_key.api_key)
    assert_nil found
  end

  test 'should return masked key' do
    api_key = LabFlowApiKey.create!(
      project: @project,
      created_by: @user
    )

    masked = api_key.masked_key
    assert masked.include?('...')
    assert_equal api_key.api_key[0..7], masked.split('...').first
    assert_equal api_key.api_key[-4..], masked.split('...').last
  end

  test 'should scope by project' do
    project2 = Project.find(2)
    key1 = LabFlowApiKey.create!(project: @project, created_by: @user)
    key2 = LabFlowApiKey.create!(project: project2, created_by: @user)

    keys = LabFlowApiKey.for_project(@project)
    assert_includes keys, key1
    assert_not_includes keys, key2
  end

  test 'should scope active keys' do
    key1 = LabFlowApiKey.create!(project: @project, created_by: @user, active: true)
    key2 = LabFlowApiKey.create!(project: @project, created_by: @user, active: false)

    keys = LabFlowApiKey.active
    assert_includes keys, key1
    assert_not_includes keys, key2
  end

  test 'should check recently used' do
    api_key = LabFlowApiKey.create!(
      project: @project,
      created_by: @user,
      last_used_at: 1.hour.ago
    )
    assert api_key.recently_used?

    api_key.update!(last_used_at: 2.days.ago)
    assert_not api_key.recently_used?
  end
end
