# frozen_string_literal: true

class IssueWikiPagesController < ApplicationController
  before_action :find_issue
  before_action :authorize

  def new
    @wiki = @issue.project.wiki
    unless @wiki
      flash[:error] = l(:error_wiki_not_enabled)
      redirect_to issue_path(@issue)
      return
    end

    @page_title = RedmineLabFlow::Helpers.generate_wiki_title_from_issue(@issue)
    @page = @wiki.find_or_new_page(@page_title)

    if @page.persisted?
      redirect_to project_wiki_page_path(@issue.project, @page.title)
      return
    end

    @content = @page.content_for_version(nil)
    @content ||= WikiContent.new(page: @page)
    @content.text = generate_initial_content
  end

  def create
    @wiki = @issue.project.wiki
    unless @wiki
      flash[:error] = l(:error_wiki_not_enabled)
      redirect_to issue_path(@issue)
      return
    end

    @page_title = params[:wiki_page][:title].presence || RedmineLabFlow::Helpers.generate_wiki_title_from_issue(@issue)
    @page = @wiki.find_or_new_page(@page_title)

    if @page.persisted?
      flash[:warning] = l(:notice_wiki_page_exists)
      redirect_to project_wiki_page_path(@issue.project, @page.title)
      return
    end

    @page.title = @page_title
    @content = WikiContent.new(page: @page)
    @content.author = User.current
    @content.text = params[:wiki_page][:content].presence || generate_initial_content

    if @page.save
      @content.save
      link_wiki_to_issue(@page)
      flash[:notice] = l(:notice_wiki_page_created)
      redirect_to project_wiki_page_path(@issue.project, @page.title)
    else
      flash[:error] = @page.errors.full_messages.join(', ')
      render :new
    end
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize
    unless User.current.allowed_to?(:edit_wiki_pages, @project)
      deny_access
    end
  end

  def generate_initial_content
    template = find_best_template
    content = template&.content || default_template_content

    # Replace placeholders
    content.gsub('{{issue_id}}', @issue.id.to_s)
           .gsub('{{issue_subject}}', @issue.subject)
           .gsub('{{issue_tracker}}', @issue.tracker.name)
           .gsub('{{issue_url}}', "/issues/#{@issue.id}")
           .gsub('{{date}}', Date.today.to_s)
           .gsub('{{author}}', User.current.name)
  end

  def find_best_template
    return nil unless LabFlowProcedureTemplate.table_exists?

    # Try to find a template matching the tracker name
    tracker_name = @issue.tracker.name.downcase
    LabFlowProcedureTemplate.active.find_by('LOWER(name) LIKE ?', "%#{tracker_name}%") ||
      LabFlowProcedureTemplate.active.first
  end

  def default_template_content
    <<~MARKDOWN
      # #{@issue.subject}

      **Issue:** ##{@issue.id} - [View Issue]({{issue_url}})
      **Tracker:** {{issue_tracker}}
      **Created:** {{date}}
      **Author:** {{author}}

      ---

      ## Objective



      ## Materials and Equipment



      ## Procedure

      1.
      2.
      3.

      ## Results



      ## Observations



      ## Conclusions


    MARKDOWN
  end

  def link_wiki_to_issue(wiki_page)
    # Find procedure reference field and update the issue
    procedure_ref_field = IssueCustomField.find_by(name: I18n.t(:field_procedure_reference))
    return unless procedure_ref_field

    # Only update if issue has this custom field available
    return unless @issue.available_custom_fields.include?(procedure_ref_field)

    version = wiki_page.content&.version || 1
    @issue.custom_field_values = { procedure_ref_field.id => "#{wiki_page.id}:#{version}" }
    @issue.save(validate: false)
  end
end
