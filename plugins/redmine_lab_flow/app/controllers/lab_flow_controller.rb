# frozen_string_literal: true

class LabFlowController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  def index
    @sample_tracker = Tracker.find_by(name: I18n.t(:label_sample))
    @daily_log_tracker = Tracker.find_by(name: I18n.t(:label_daily_log))
    @assay_tracker = Tracker.find_by(name: I18n.t(:label_assay))

    @samples_count = @sample_tracker ? @project.issues.where(tracker: @sample_tracker).count : 0
    @logs_count = @daily_log_tracker ? @project.issues.where(tracker: @daily_log_tracker).count : 0
    @assays_count = @assay_tracker ? @project.issues.where(tracker: @assay_tracker).count : 0

    @recent_samples = @sample_tracker ? @project.issues.where(tracker: @sample_tracker).order(created_on: :desc).limit(5) : []
    @recent_logs = @daily_log_tracker ? @project.issues.where(tracker: @daily_log_tracker).order(created_on: :desc).limit(5) : []
    @recent_assays = @assay_tracker ? @project.issues.where(tracker: @assay_tracker).order(created_on: :desc).limit(5) : []
  end
end
