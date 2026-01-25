# frozen_string_literal: true

module RedmineLabFlow
  class MetricsCalculator
    def initialize(project)
      @project = project
    end

    # Calculate daily metrics for all trackers
    def calculate_daily_metrics(date = Date.yesterday)
      lab_trackers = @project.trackers.where(name: %w[Sample Assay Experiment])

      lab_trackers.each do |tracker|
        calculate_tracker_metrics(tracker, date)
      end
    end

    # Detect issues that have been stuck in a status for too long
    def detect_starvation(threshold_hours: 48)
      Issue.where(project: @project)
           .where('updated_on < ?', threshold_hours.hours.ago)
           .joins(:status)
           .where.not(issue_statuses: { is_closed: true })
           .joins(:tracker)
           .where(trackers: { name: %w[Sample Assay Experiment] })
           .map do |issue|
        {
          issue: issue,
          hours_stuck: ((Time.current - issue.updated_on) / 1.hour).round(1),
          status: issue.status.name,
          tracker: issue.tracker.name
        }
      end
    end

    # Analyze bottlenecks - where issues spend the most time
    def bottleneck_analysis
      results = {}
      lab_trackers = @project.trackers.where(name: %w[Sample Assay Experiment])
      issues = @project.issues.where(tracker: lab_trackers)

      issues.find_each do |issue|
        analyze_issue_flow(issue, results)
      end

      results.transform_values do |data|
        {
          status_name: data[:name],
          avg_hours: data[:total_count] > 0 ? (data[:total_hours] / data[:total_count]).round(1) : 0,
          total_count: data[:total_count],
          max_hours: data[:max_hours]
        }
      end.sort_by { |_, v| -v[:avg_hours] }.to_h
    end

    # Calculate throughput (issues completed per time period)
    def throughput(days: 30)
      lab_trackers = @project.trackers.where(name: %w[Sample Assay Experiment])
      closed_statuses = IssueStatus.where(is_closed: true)

      @project.issues
              .where(tracker: lab_trackers)
              .where(status: closed_statuses)
              .where('closed_on >= ?', days.days.ago)
              .group('DATE(closed_on)')
              .count
    end

    private

    def calculate_tracker_metrics(tracker, date)
      issues = @project.issues.where(tracker: tracker)

      issues.group(:status_id).count.each do |status_id, count|
        avg_time = calculate_avg_time_in_status(tracker, status_id)

        LabFlowWorkflowMetric.find_or_initialize_by(
          project: @project,
          tracker: tracker,
          status_id: status_id,
          date: date
        ).update!(
          count: count,
          avg_time_in_status_hours: avg_time
        )
      end
    end

    def calculate_avg_time_in_status(tracker, status_id)
      issues = @project.issues
                       .where(tracker: tracker)
                       .where(status_id: status_id)

      return 0 if issues.empty?

      total_hours = 0
      count = 0

      issues.each do |issue|
        hours = time_in_current_status(issue)
        if hours
          total_hours += hours
          count += 1
        end
      end

      count > 0 ? (total_hours / count).round(2) : 0
    end

    def time_in_current_status(issue)
      last_status_change = issue.journals
                                .joins(:details)
                                .where(journal_details: { prop_key: 'status_id', value: issue.status_id.to_s })
                                .order(created_on: :desc)
                                .first

      if last_status_change
        ((Time.current - last_status_change.created_on) / 1.hour).round(2)
      else
        ((Time.current - issue.created_on) / 1.hour).round(2)
      end
    end

    def analyze_issue_flow(issue, results)
      journals = issue.journals.includes(:details).order(:created_on)
      previous_status_change = issue.created_on
      previous_status_id = nil

      journals.each do |journal|
        status_change = journal.details.find { |d| d.prop_key == 'status_id' }
        next unless status_change

        if previous_status_id
          hours = ((journal.created_on - previous_status_change) / 1.hour).round(2)

          results[previous_status_id] ||= { name: IssueStatus.find_by(id: previous_status_id)&.name, total_hours: 0, total_count: 0, max_hours: 0 }
          results[previous_status_id][:total_hours] += hours
          results[previous_status_id][:total_count] += 1
          results[previous_status_id][:max_hours] = [results[previous_status_id][:max_hours], hours].max
        end

        previous_status_id = status_change.value.to_i
        previous_status_change = journal.created_on
      end
    end
  end
end
