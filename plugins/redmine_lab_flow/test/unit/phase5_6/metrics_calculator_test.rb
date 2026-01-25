# frozen_string_literal: true

require_relative '../../test_helper'

class MetricsCalculatorTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :issue_statuses, :issues

  def setup
    @project = Project.find(1)
  end

  def test_calculate_daily_metrics
    skip "MetricsCalculator not available" unless defined?(RedmineLabFlow::MetricsCalculator)

    calculator = RedmineLabFlow::MetricsCalculator.new(@project)

    # Should not raise any errors
    assert_nothing_raised do
      calculator.calculate_daily_metrics
    end
  end

  def test_detect_starvation
    skip "MetricsCalculator not available" unless defined?(RedmineLabFlow::MetricsCalculator)

    calculator = RedmineLabFlow::MetricsCalculator.new(@project)

    # Create an old issue
    old_issue = Issue.create!(
      project: @project,
      tracker: Tracker.first,
      subject: 'Stale Issue',
      author: User.first,
      status: IssueStatus.first,
      priority: IssuePriority.first
    )
    old_issue.update_column(:updated_on, 10.days.ago)

    stuck = calculator.detect_starvation(threshold_hours: 168) # 7 days

    assert stuck.is_a?(Array)
  end

  def test_bottleneck_analysis
    skip "MetricsCalculator not available" unless defined?(RedmineLabFlow::MetricsCalculator)

    calculator = RedmineLabFlow::MetricsCalculator.new(@project)
    result = calculator.bottleneck_analysis

    assert result.is_a?(Hash)
  end

  def test_throughput
    skip "MetricsCalculator not available" unless defined?(RedmineLabFlow::MetricsCalculator)

    calculator = RedmineLabFlow::MetricsCalculator.new(@project)
    result = calculator.throughput(days: 30)

    assert result.is_a?(Hash)
  end
end
