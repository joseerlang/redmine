# frozen_string_literal: true

module RedmineLabFlow
  class WikiReferenceFormat < Redmine::FieldFormat::Base
    add 'wiki_reference'

    self.customized_class_names = %w[Issue]
    self.form_partial = 'custom_fields/formats/wiki_reference'
    self.searchable_supported = false
    self.multiple_supported = false
    self.is_filter_supported = true

    def label
      'label_wiki_reference'
    end

    # Value format: "wiki_page_id:version"
    def cast_single_value(custom_field, value, customized = nil)
      return nil if value.blank?

      parts = value.to_s.split(':')
      return nil if parts.size != 2

      wiki_page_id, version = parts
      wiki_page = WikiPage.find_by(id: wiki_page_id.to_i)
      return nil unless wiki_page

      { wiki_page: wiki_page, version: version.to_i }
    end

    def formatted_value(view, custom_field, value, customized = nil, html = false)
      return '' if value.blank?

      casted = cast_single_value(custom_field, value, customized)
      return '' if casted.nil?

      wiki_page = casted[:wiki_page]
      version = casted[:version]
      title = "#{wiki_page.pretty_title} (v#{version})"

      if html
        begin
          url = view.url_for(
            controller: 'wiki',
            action: 'show',
            project_id: wiki_page.wiki.project,
            id: wiki_page.title,
            version: version
          )
          view.link_to(title, url)
        rescue StandardError
          title
        end
      else
        title
      end
    end

    def possible_values_options(custom_field, object = nil)
      return [] unless object.respond_to?(:project) && object.project

      wiki = object.project.wiki
      return [] unless wiki

      wiki.pages.includes(:content).map do |page|
        version = page.content&.version || 1
        ["#{page.pretty_title} (v#{version})", "#{page.id}:#{version}"]
      end.sort_by(&:first)
    end

    def edit_tag(view, tag_id, tag_name, custom_value, options = {})
      wiki_pages = possible_values_options(custom_value.custom_field, custom_value.customized)
      blank_option = custom_value.custom_field.is_required? ? '' : [[l(:label_none), '']]

      view.select_tag(
        tag_name,
        view.options_for_select((blank_option || []) + wiki_pages, custom_value.value),
        options.merge(id: tag_id)
      )
    end

    def bulk_edit_tag(view, tag_id, tag_name, custom_field, objects, value, options = {})
      opts = [[l(:label_no_change_option), '']]
      opts << [l(:label_none), '__none__'] unless custom_field.is_required?

      if objects.first.respond_to?(:project) && objects.first.project
        opts += possible_values_options(custom_field, objects.first)
      end

      view.select_tag(tag_name, view.options_for_select(opts, value), options.merge(id: tag_id))
    end

    def validate_custom_value(custom_value)
      return [] if custom_value.value.blank?

      parts = custom_value.value.to_s.split(':')
      if parts.size != 2
        return [::I18n.t('activerecord.errors.messages.invalid')]
      end

      wiki_page = WikiPage.find_by(id: parts[0].to_i)
      unless wiki_page
        return [::I18n.t('activerecord.errors.messages.invalid')]
      end

      []
    end

    def query_filter_options(_custom_field, query)
      {
        type: :list_optional,
        values: -> { query_filter_values(query) }
      }
    end

    private

    def query_filter_values(query)
      return [] unless query.project

      wiki = query.project.wiki
      return [] unless wiki

      wiki.pages.map do |page|
        version = page.content&.version || 1
        ["#{page.pretty_title} (v#{version})", "#{page.id}:#{version}"]
      end.sort_by(&:first)
    end
  end
end
