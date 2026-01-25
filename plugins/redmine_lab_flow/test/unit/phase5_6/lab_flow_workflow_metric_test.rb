# frozen_string_literal: true

require_relative '../../test_helper'

class LabFlowWorkflowMetricTest < ActiveSupport::TestCase
  fixtures :projects, :trackers, :issue_statuses

  def setup
    @project = Project.find(1)
    @tracker = Tracker.first
    @status = IssueStatus.first
  end

  def test_create_valid_metric
    skip "LabFlowWorkflowMetric not available" unless defined?(LabFlowWorkflowMetric)

    metric = LabFlowWorkflowMetric.new(
      project: @project,
      tracker: @tracker,
      status: @status,
      date: Date.current,
      count: 10,
      avg_time_in_status_hours: 24.5
    )

    assert metric.valid?, "Metric should be valid: #{metric.errors.full_messages.join(', ')}"
    assert metric.save
  end

  def test_requires_project
    skip "LabFlowWorkflowMetric not available" unless defined?(LabFlowWorkflowMetric)

    metric = LabFlowWorkflowMetric.new(
      tracker: @tracker,
      status: @status,
      date: Date.current,
      count: 10
    )

    assert_not metric.valid?
    assert metric.errors[:project].present?
  end

  def test_scopes
    skip "LabFlowWorkflowMetric not available" unless defined?(LabFlowWorkflowMetric)

    metric = LabFlowWorkflowMetric.create!(
      project: @project,
      tracker: @tracker,
      status: @status,
      date: Date.current,
      count: 10
    )

    assert_includes LabFlowWorkflowMetric.by_project(@project), metric
    assert_includes LabFlowWorkflowMetric.by_date_range(1.week.ago, 1.week.from_now), metric
    assert_includes LabFlowWorkflowMetric.by_tracker(@tracker), metric
  end
end
