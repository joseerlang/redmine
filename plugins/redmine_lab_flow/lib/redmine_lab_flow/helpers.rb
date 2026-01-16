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

      def find_linked_wiki_page(issue)
        return nil unless issue&.project&.wiki

        # First check if there's a Wiki page with the issue's subject as title
        wiki = issue.project.wiki
        page_title = issue.subject.to_s.gsub(/\s+/, '-').gsub(/[^\w\-]/, '')
        wiki_page = wiki.find_page(page_title)
        return wiki_page if wiki_page

        # Check for procedure reference custom field
        procedure_ref_field = IssueCustomField.find_by(name: I18n.t(:field_procedure_reference))
        return nil unless procedure_ref_field

        ref_value = issue.custom_field_value(procedure_ref_field)
        return nil if ref_value.blank?

        # Parse wiki_page_id:version format
        parts = ref_value.to_s.split(':')
        return nil if parts.size != 2

        WikiPage.find_by(id: parts[0].to_i)
      end

      def generate_wiki_title_from_issue(issue)
        "#{issue.tracker.name}-#{issue.id}-#{issue.subject}".gsub(/\s+/, '-').gsub(/[^\w\-]/, '')[0..50]
      end
    end
  end
end
