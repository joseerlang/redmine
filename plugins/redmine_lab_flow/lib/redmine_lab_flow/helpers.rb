# frozen_string_literal: true

module RedmineLabFlow
  module Helpers
    class << self
      def issue_is_finalized?(issue)
        return false unless issue&.status

        finalized_status = RedmineLabFlow::Setup.finalized_status
        return false unless finalized_status

        issue.status_id == finalized_status.id
      end

      def issue_is_daily_log?(issue)
        return false unless issue&.tracker

        daily_log_tracker = RedmineLabFlow::Setup.daily_log_tracker
        return false unless daily_log_tracker

        issue.tracker_id == daily_log_tracker.id
      end

      def issue_requires_reason_for_change?(issue)
        return false if issue.nil? || issue.new_record?

        issue_is_daily_log?(issue)
      end

      def issue_finalized_editable?(issue, user)
        return false unless issue_is_finalized?(issue)
        return false unless user&.admin?

        settings = LabFlowProjectSetting.for_project(issue.project)
        settings.allow_admin_unlock_finalized
      end
    end
  end
end
