# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class LabFlowApiControllerTest < ActionController::TestCase
  fixtures :users, :projects, :trackers, :issue_statuses, :issues, :custom_fields

  def setup
    @user = User.find(1) # admin
    @project = Project.find(1)

    # Ensure Assay tracker exists
    @assay_tracker = Tracker.find_or_create_by!(name: 'Assay') do |t|
      t.default_status = IssueStatus.first
    end

    # Create Internal ID custom field
    @internal_id_field = IssueCustomField.find_or_create_by!(name: 'Internal ID') do |f|
      f.field_format = 'string'
      f.is_for_all = true
    end
    @assay_tracker.custom_fields << @internal_id_field unless @assay_tracker.custom_fields.include?(@internal_id_field)

    # Create test assay with Internal ID
    @assay = Issue.create!(
      project: @project,
      tracker: @assay_tracker,
      subject: 'Test Assay for API',
      author: @user
    )
    @assay.custom_field_values = { @internal_id_field.id => 'TEST-001' }
    @assay.save!

    # Create API key
    @api_key = LabFlowApiKey.create!(
      project: @project,
      created_by: @user,
      description: 'Test Key'
    )
  end

  test 'should show assay with valid api key' do
    @request.headers['X-API-Key'] = @api_key.api_key
    get :show_assay, params: { internal_id: 'TEST-001' }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @assay.id, json['id']
    assert_equal 'TEST-001', json['internal_id']
  end

  test 'should reject request without api key' do
    get :show_assay, params: { internal_id: 'TEST-001' }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert json['error'].present?
  end

  test 'should reject request with invalid api key' do
    @request.headers['X-API-Key'] = 'invalid_key'
    get :show_assay, params: { internal_id: 'TEST-001' }

    assert_response :unauthorized
  end

  test 'should return 404 for non-existent assay' do
    @request.headers['X-API-Key'] = @api_key.api_key
    get :show_assay, params: { internal_id: 'NONEXISTENT' }

    assert_response :not_found
  end

  test 'should update assay with valid api key' do
    @request.headers['X-API-Key'] = @api_key.api_key
    @request.headers['Content-Type'] = 'application/json'

    post :update_assay, params: {
      internal_id: 'TEST-001',
      notes: 'Updated from test'
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert json['success']
  end

  test 'should accept user api token' do
    @user.api_key = 'test_user_token'
    @user.save!

    @request.headers['X-Redmine-API-Key'] = 'test_user_token'
    get :show_assay, params: { internal_id: 'TEST-001' }

    assert_response :success
  end

  test 'should deny access to other projects assay with project api key' do
    # Create assay in different project
    project2 = Project.find(2)
    assay2 = Issue.create!(
      project: project2,
      tracker: @assay_tracker,
      subject: 'Other Project Assay',
      author: @user
    )
    assay2.custom_field_values = { @internal_id_field.id => 'OTHER-001' }
    assay2.save!

    @request.headers['X-API-Key'] = @api_key.api_key
    get :show_assay, params: { internal_id: 'OTHER-001' }

    assert_response :forbidden
  end
end
