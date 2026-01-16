# frozen_string_literal: true

require_relative '../test_helper'

class LabFlowIntegrationTest < Redmine::IntegrationTest
  fixtures :projects, :users, :roles, :members, :member_roles,
           :trackers, :issue_statuses, :enabled_modules, :issues,
           :enumerations

  ISSUE_COUNT_MODEL = 'Issue'

  def setup
    @project = Project.find(1)
    @admin = User.find(1)

    require_relative '../../lib/redmine_lab_flow/setup'
    RedmineLabFlow::Setup.install
    @project.enable_module!(:laboratory_management)

    # Associate trackers with project
    sample_tracker = Tracker.find_by(name: I18n.t(:label_sample))
    daily_log_tracker = Tracker.find_by(name: I18n.t(:label_daily_log))
    assay_tracker = Tracker.find_by(name: I18n.t(:label_assay))

    @project.trackers << sample_tracker unless @project.trackers.include?(sample_tracker)
    @project.trackers << daily_log_tracker unless @project.trackers.include?(daily_log_tracker)
    @project.trackers << assay_tracker unless @project.trackers.include?(assay_tracker)
  end

  test "create Sample issue with Internal ID" do
    log_user('admin', 'admin')

    sample_tracker = Tracker.find_by(name: I18n.t(:label_sample))
    internal_id_field = IssueCustomField.find_by(name: I18n.t(:field_internal_id))

    assert_difference "#{ISSUE_COUNT_MODEL}.count" do
      post "/projects/#{@project.identifier}/issues", params: {
        issue: {
          tracker_id: sample_tracker.id,
          subject: 'Test Sample',
          status_id: IssueStatus.first.id,
          priority_id: IssuePriority.default.id,
          custom_field_values: {
            internal_id_field.id.to_s => 'SAMPLE-001'
          }
        }
      }
    end

    issue = Issue.last
    assert_equal 'Test Sample', issue.subject
    assert_equal sample_tracker.id, issue.tracker_id
    assert_equal 'SAMPLE-001', issue.custom_field_value(internal_id_field)
  end

  test "create Assay issue with Measured Value and Unit" do
    log_user('admin', 'admin')

    assay_tracker = Tracker.find_by(name: I18n.t(:label_assay))
    measured_value_field = IssueCustomField.find_by(name: I18n.t(:field_measured_value))
    unit_field = IssueCustomField.find_by(name: I18n.t(:field_unit))

    assert_difference "#{ISSUE_COUNT_MODEL}.count" do
      post "/projects/#{@project.identifier}/issues", params: {
        issue: {
          tracker_id: assay_tracker.id,
          subject: 'Test Assay',
          status_id: IssueStatus.first.id,
          priority_id: IssuePriority.default.id,
          custom_field_values: {
            measured_value_field.id.to_s => '42.5',
            unit_field.id.to_s => 'mg'
          }
        }
      }
    end

    issue = Issue.last
    assert_equal 'Test Assay', issue.subject
    assert_equal assay_tracker.id, issue.tracker_id
  end

  test "create Daily Log issue with Experiment Reference" do
    log_user('admin', 'admin')

    daily_log_tracker = Tracker.find_by(name: I18n.t(:label_daily_log))
    experiment_ref_field = IssueCustomField.find_by(name: I18n.t(:field_experiment_reference))
    observations_field = IssueCustomField.find_by(name: I18n.t(:field_observations))

    assert_difference "#{ISSUE_COUNT_MODEL}.count" do
      post "/projects/#{@project.identifier}/issues", params: {
        issue: {
          tracker_id: daily_log_tracker.id,
          subject: 'Test Daily Log',
          status_id: IssueStatus.first.id,
          priority_id: IssuePriority.default.id,
          custom_field_values: {
            experiment_ref_field.id.to_s => 'EXP-2024-001',
            observations_field.id.to_s => 'Sample processed correctly'
          }
        }
      }
    end

    issue = Issue.last
    assert_equal 'Test Daily Log', issue.subject
    assert_equal daily_log_tracker.id, issue.tracker_id
    assert_equal 'EXP-2024-001', issue.custom_field_value(experiment_ref_field)
  end

  test "lab flow dashboard is accessible" do
    log_user('admin', 'admin')

    get "/projects/#{@project.identifier}/lab_flow"
    assert_response :success
    assert_select 'h2', text: I18n.t(:label_lab_flow)
  end
end
