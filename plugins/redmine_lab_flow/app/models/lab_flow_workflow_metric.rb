# frozen_string_literal: true

class LabFlowWorkflowMetric < ActiveRecord::Base
  belongs_to :project
  belongs_to :tracker
  belongs_to :status, class_name: 'IssueStatus'

  validates :project, :tracker, :status, :date, presence: true
  validates :count, numericality: { greater_than_or_equal_to: 0 }

  scope :by_project, ->(project) { where(project: project) }
  scope :by_tracker, ->(tracker) { where(tracker: tracker) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, ->(days = 30) { where('date >= ?', days.days.ago.to_date) }

  # Aggregate metrics by status for a project
  def self.aggregate_by_status(project, start_date: 30.days.ago.to_date, end_date: Date.current)
    by_project(project)
      .by_date_range(start_date, end_date)
      .group(:status_id)
      .select(
        'status_id',
        'SUM(count) as total_count',
        'AVG(avg_time_in_status_hours) as overall_avg_time'
      )
  end

  # Get daily trend for a specific tracker
  def self.daily_trend(project, tracker, days: 30)
    by_project(project)
      .by_tracker(tracker)
      .recent(days)
      .group(:date)
      .order(:date)
      .select('date, SUM(count) as daily_count')
  end

  # Detect issues that have been stuck in a status for too long
  def self.starvation_candidates(project, threshold_hours: 48)
    Issue.where(project: project)
         .where('updated_on < ?', threshold_hours.hours.ago)
         .joins(:status)
         .where.not(issue_statuses: { is_closed: true })
  end
end
