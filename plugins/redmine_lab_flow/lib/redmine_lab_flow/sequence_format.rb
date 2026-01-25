# frozen_string_literal: true

module RedmineLabFlow
  class SequenceFormat < Redmine::FieldFormat::Base
    add 'sequence'
    self.searchable_supported = false
    self.form_partial = 'custom_fields/formats/sequence'

    def label
      'label_sequence_format'
    end

    def cast_single_value(custom_field, value, customized = nil)
      value.to_s.strip
    end

    def validate_single_value(custom_field, value, customized = nil)
      errs = super
      return errs if value.blank?

      # Validate sequence ID reference
      if value =~ /^\d+$/
        unless LabFlowSequence.exists?(value.to_i)
          errs << ::I18n.t('activerecord.errors.messages.invalid_sequence_reference')
        end
      end

      errs
    end

    def formatted_value(view, custom_field, value, customized = nil, html = false)
      return '' if value.blank?

      if html && value =~ /^\d+$/
        sequence_html(view, value.to_i, customized)
      elsif html
        # Direct sequence text display
        sequence_preview_html(view, value)
      else
        value
      end
    end

    def edit_tag(view, tag_id, tag_name, custom_value, options = {})
      value = custom_value.value || ''
      issue = custom_value.customized

      view.content_tag(:div, class: 'sequence-input-container') do
        content = ''

        if issue.is_a?(Issue) && issue.persisted?
          # Show existing sequences for selection
          sequences = issue.lab_flow_sequences

          if sequences.any?
            content += view.select_tag(
              tag_name,
              view.options_from_collection_for_select(sequences, :id, :name, value),
              options.merge(
                id: tag_id,
                include_blank: I18n.t('label_select_sequence'),
                class: 'sequence-select'
              )
            )
          end

          # Link to add new sequence
          content += view.link_to(
            I18n.t('label_add_sequence'),
            view.url_for(controller: 'lab_flow_sequences', action: 'new', issue_id: issue.id),
            class: 'icon icon-add sequence-add-link'
          )
        else
          # For new issues, just show a text field for sequence data
          content += view.text_area_tag(
            tag_name,
            value,
            options.merge(
              id: tag_id,
              rows: 4,
              class: 'sequence-data-input',
              placeholder: 'Enter sequence (FASTA format supported)'
            )
          )
        end

        content.html_safe
      end
    end

    def bulk_edit_tag(view, tag_id, tag_name, custom_field, objects, value, options = {})
      # Bulk edit not fully supported for sequence references
      view.text_field_tag(tag_name, '', options.merge(
        id: tag_id,
        placeholder: 'Sequence ID',
        class: 'sequence-id-input'
      ))
    end

    def query_filter_options(custom_field, query)
      { type: :text }
    end

    private

    def sequence_html(view, sequence_id, customized)
      sequence = LabFlowSequence.find_by(id: sequence_id)
      return I18n.t('label_sequence_not_found') unless sequence

      view.content_tag(:div, class: 'sequence-viewer-container', 'data-sequence-id' => sequence.id) do
        content = view.content_tag(:div, class: 'sequence-header') do
          header = view.content_tag(:span, sequence.name, class: 'sequence-name')
          header += view.content_tag(:span, sequence.sequence_type.upcase, class: "sequence-type sequence-type-#{sequence.sequence_type}")
          header += view.content_tag(:span, "#{sequence.length} bp", class: 'sequence-length')
          header += view.content_tag(:span, 'circular', class: 'sequence-circular') if sequence.circular?
          header
        end

        # SeqViz container
        content += view.content_tag(:div, '',
          class: 'seqviz-container',
          id: "seqviz_#{sequence.id}",
          'data-sequence' => sequence.sequence_data,
          'data-name' => sequence.name,
          'data-type' => sequence.sequence_type,
          'data-circular' => sequence.circular?.to_s,
          'data-annotations' => sequence.annotations.map(&:to_seqviz).to_json
        )

        # Sequence info
        content += view.content_tag(:div, class: 'sequence-info') do
          info = view.content_tag(:span, "GC: #{sequence.gc_content}%", class: 'sequence-gc') if sequence.gc_content
          info ||= ''
          info += view.content_tag(:span, "#{sequence.annotations.count} annotations", class: 'sequence-annotations-count')
          info.html_safe
        end

        # Links
        content += view.content_tag(:div, class: 'sequence-links') do
          view.link_to(I18n.t('label_view_sequence'), view.url_for(controller: 'lab_flow_sequences', action: 'show', issue_id: sequence.issue_id, id: sequence.id)) +
          ' | ' +
          view.link_to(I18n.t('label_export_fasta'), view.url_for(controller: 'lab_flow_sequences', action: 'export', issue_id: sequence.issue_id, id: sequence.id, export_format: 'fasta'))
        end

        content
      end
    end

    def sequence_preview_html(view, sequence_data)
      # Preview for inline sequence data (not a reference)
      clean_seq = sequence_data.gsub(/\s/, '').upcase

      view.content_tag(:div, class: 'sequence-preview') do
        # Show first 100 characters
        preview = clean_seq.length > 100 ? "#{clean_seq[0..99]}..." : clean_seq
        view.content_tag(:code, preview, class: 'sequence-code') +
        view.content_tag(:span, "#{clean_seq.length} bp", class: 'sequence-length')
      end
    end
  end
end
