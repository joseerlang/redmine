# frozen_string_literal: true

module RedmineLabFlow
  class Hooks < Redmine::Hook::ViewListener
    # Project sidebar hook (existing)
    render_on :view_projects_show_sidebar_bottom,
              partial: 'hooks/redmine_lab_flow/project_sidebar'

    # CSS/JS for visualizers and styling
    render_on :view_layouts_base_html_head,
              partial: 'hooks/redmine_lab_flow/html_head'

    # Issue show details - finalized badge + Phase 5/6 links
    def view_issues_show_details_bottom(context = {})
      issue = context[:issue]
      return '' unless issue

      context[:controller].send(:render_to_string, {
        partial: 'hooks/redmine_lab_flow/issue_show_details',
        locals: { issue: issue }
      })
    end

    # Issue description bottom - Wiki actions + Sequences panel
    def view_issues_show_description_bottom(context = {})
      issue = context[:issue]
      return '' unless issue

      output = context[:controller].send(:render_to_string, {
        partial: 'hooks/redmine_lab_flow/issue_wiki_actions',
        locals: { issue: issue }
      })

      # Phase 6.2: Sequence viewer panel
      if defined?(LabFlowSequence) && issue.respond_to?(:lab_flow_sequences) && issue.lab_flow_sequences.any?
        output += context[:controller].send(:render_to_string, {
          partial: 'hooks/redmine_lab_flow/sequences_panel',
          locals: { issue: issue, sequences: issue.lab_flow_sequences }
        })
      end

      output
    rescue StandardError => e
      Rails.logger.error "[RedmineLabFlow] Issue description hook error: #{e.message}"
      ''
    end

    # Issue edit notes - reason for change requirement
    def view_issues_edit_notes_bottom(context = {})
      issue = context[:issue]
      return '' unless issue

      context[:controller].send(:render_to_string, {
        partial: 'hooks/redmine_lab_flow/issue_edit_notes',
        locals: { issue: issue }
      })
    end

    # Wiki edit form - template selector
    def view_wiki_edit_form_bottom(context = {})
      return '' unless context[:page]&.new_record?
      return '' if LabFlowProcedureTemplate.table_exists? && LabFlowProcedureTemplate.active.none?

      context[:controller].send(:render_to_string, {
        partial: 'hooks/redmine_lab_flow/wiki_edit_template_selector',
        locals: {
          page: context[:page],
          project: context[:project]
        }
      })
    rescue StandardError
      ''
    end

    # Phase 4: Electronic signature modal for status changes
    def view_issues_form_details_bottom(context = {})
      issue = context[:issue]
      return '' unless issue

      # Only show for Assay and Sample trackers
      return '' unless issue.respond_to?(:assay?) && (issue.assay? || issue.sample?)

      context[:controller].send(:render_to_string, {
        partial: 'hooks/redmine_lab_flow/signature_modal',
        locals: { issue: issue }
      })
    rescue StandardError => e
      Rails.logger.error "[RedmineLabFlow] Signature modal hook error: #{e.message}"
      ''
    end

    # Phase 5.1: Dashboard link in project overview
    def view_projects_show_right(context = {})
      project = context[:project]
      return '' unless project&.module_enabled?(:laboratory_management)

      context[:controller].send(:render_to_string, {
        partial: 'hooks/redmine_lab_flow/project_dashboard_link',
        locals: { project: project }
      })
    rescue StandardError
      ''
    end

    # Phase 5.4: FAIR metadata panel on issue sidebar
    def view_issues_show_sidebar_bottom(context = {})
      issue = context[:issue]
      return '' unless issue

      output = ''

      # FAIR metadata panel
      if defined?(LabFlowFairMetadata)
        output += context[:controller].send(:render_to_string, {
          partial: 'hooks/redmine_lab_flow/fair_metadata_panel',
          locals: { issue: issue }
        })
      end

      # External jobs panel
      if defined?(LabFlowExternalJob) && issue.respond_to?(:lab_flow_external_jobs)
        jobs = LabFlowExternalJob.for_issue(issue).recent(5)
        if jobs.any?
          output += context[:controller].send(:render_to_string, {
            partial: 'hooks/redmine_lab_flow/external_jobs_panel',
            locals: { issue: issue, jobs: jobs }
          })
        end
      end

      output
    rescue StandardError => e
      Rails.logger.error "[RedmineLabFlow] Issue sidebar hook error: #{e.message}"
      ''
    end
  end
end
