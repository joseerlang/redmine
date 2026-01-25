# frozen_string_literal: true

class LabFlowDashboardController < ApplicationController
  before_action :find_project
  before_action :authorize

  def index
    @trackers = @project.trackers.where(name: %w[Sample Assay Experiment])
    @recent_days = params[:days].to_i.positive? ? params[:days].to_i : 30

    # Get starvation alerts
    @starvation_issues = LabFlowWorkflowMetric.starvation_candidates(
      @project,
      threshold_hours: Setting.plugin_redmine_lab_flow['starvation_threshold_hours']&.to_i || 48
    ).limit(10)

    # Get metrics summary
    @metrics_summary = calculate_metrics_summary
  end

  def metrics
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current
    tracker_id = params[:tracker_id]

    metrics = LabFlowWorkflowMetric.by_project(@project)
                                   .by_date_range(start_date, end_date)

    metrics = metrics.by_tracker(Tracker.find(tracker_id)) if tracker_id.present?

    respond_to do |format|
      format.json do
        render json: {
          labels: metrics.group(:date).order(:date).pluck(:date).map(&:to_s),
          datasets: build_chart_datasets(metrics)
        }
      end
    end
  end

  def starvation
    threshold = params[:threshold_hours]&.to_i || 48

    issues = LabFlowWorkflowMetric.starvation_candidates(@project, threshold_hours: threshold)
                                  .includes(:status, :tracker, :assigned_to)
                                  .limit(50)

    respond_to do |format|
      format.json do
        render json: issues.map { |issue|
          {
            id: issue.id,
            subject: issue.subject,
            status: issue.status.name,
            tracker: issue.tracker.name,
            assigned_to: issue.assigned_to&.name,
            hours_stuck: ((Time.current - issue.updated_on) / 1.hour).round(1),
            url: issue_path(issue)
          }
        }
      end
    end
  end

  def bottlenecks
    # Analyze where issues spend the most time
    metrics = LabFlowWorkflowMetric.by_project(@project)
                                   .recent(30)
                                   .group(:status_id)
                                   .select('status_id, AVG(avg_time_in_status_hours) as avg_hours, SUM(count) as total_count')

    respond_to do |format|
      format.json do
        render json: metrics.map { |m|
          status = IssueStatus.find_by(id: m.status_id)
          {
            status_id: m.status_id,
            status_name: status&.name || 'Unknown',
            avg_hours: m.avg_hours&.round(1),
            total_count: m.total_count
          }
        }
      end
    end
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def calculate_metrics_summary
    trackers = @project.trackers.where(name: %w[Sample Assay Experiment])

    summary = {}
    trackers.each do |tracker|
      issues = @project.issues.where(tracker: tracker)
      summary[tracker.name] = {
        total: issues.count,
        open: issues.open.count,
        closed: issues.where(status: IssueStatus.where(is_closed: true)).count,
        in_progress: issues.where(status: IssueStatus.where(is_closed: false).where.not(name: 'New')).count
      }
    end
    summary
  end

  def build_chart_datasets(metrics)
    statuses = IssueStatus.all.index_by(&:id)
    colors = %w[#4CAF50 #2196F3 #FF9800 #F44336 #9C27B0 #00BCD4 #FFEB3B]

    metrics.group(:status_id).pluck(:status_id).map.with_index do |status_id, idx|
      status_metrics = metrics.where(status_id: status_id)
                              .group(:date)
                              .order(:date)
                              .sum(:count)

      {
        label: statuses[status_id]&.name || "Status #{status_id}",
        data: status_metrics.values,
        backgroundColor: colors[idx % colors.length],
        borderColor: colors[idx % colors.length]
      }
    end
  end
end
