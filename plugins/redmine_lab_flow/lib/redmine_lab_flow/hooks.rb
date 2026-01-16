# frozen_string_literal: true

module RedmineLabFlow
  class Hooks < Redmine::Hook::ViewListener
    # Project sidebar hook (existing)
    render_on :view_projects_show_sidebar_bottom,
              partial: 'hooks/redmine_lab_flow/project_sidebar'

    # CSS styles for finalization badge
    render_on :view_layouts_base_html_head,
              partial: 'hooks/redmine_lab_flow/html_head'

    # Issue show details - finalized badge
    def view_issues_show_details_bottom(context = {})
      issue = context[:issue]
      return '' unless issue

      context[:controller].send(:render_to_string, {
        partial: 'hooks/redmine_lab_flow/issue_show_details',
        locals: { issue: issue }
      })
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
  end
end
