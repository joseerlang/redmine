# frozen_string_literal: true

require_relative '../test_helper'

class LabFlowControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :roles, :members, :member_roles,
           :trackers, :issue_statuses, :enabled_modules

  def setup
    @project = Project.find(1)
    @user = User.find(2)  # jsmith
    @admin = User.find(1) # admin

    # Setup lab flow
    require_relative '../../lib/redmine_lab_flow/setup'
    RedmineLabFlow::Setup.install

    # Enable module for project
    @project.enable_module!(:laboratory_management)

    # Grant permission to user's role
    role = @user.roles_for_project(@project).first
    role.add_permission!(:view_lab_entities) if role
  end

  # --- Access Control Tests ---

  test "index requires login" do
    @request.session[:user_id] = nil
    get :index, params: { project_id: @project.identifier }
    assert_response :redirect
  end

  test "index requires laboratory_management module to be enabled" do
    @project.disable_module!(:laboratory_management)
    @request.session[:user_id] = @user.id

    get :index, params: { project_id: @project.identifier }
    assert_response 403
  end

  test "index is accessible with proper permission" do
    @request.session[:user_id] = @user.id
    get :index, params: { project_id: @project.identifier }
    assert_response :success
  end

  test "admin can access index" do
    @request.session[:user_id] = @admin.id
    get :index, params: { project_id: @project.identifier }
    assert_response :success
  end

  # --- Content Tests ---

  test "index displays lab flow header" do
    @request.session[:user_id] = @admin.id
    get :index, params: { project_id: @project.identifier }

    assert_response :success
    assert_select 'h2', text: I18n.t(:label_lab_flow)
  end

  test "index displays Sample tracker section" do
    @request.session[:user_id] = @admin.id
    get :index, params: { project_id: @project.identifier }

    assert_select 'legend', text: /#{I18n.t(:label_sample_plural)}/
  end

  test "index displays Daily Log tracker section" do
    @request.session[:user_id] = @admin.id
    get :index, params: { project_id: @project.identifier }

    assert_select 'legend', text: /#{I18n.t(:label_daily_log)}/
  end

  test "index displays Assay tracker section" do
    @request.session[:user_id] = @admin.id
    get :index, params: { project_id: @project.identifier }

    assert_select 'legend', text: /#{I18n.t(:label_assay)}/
  end
end
