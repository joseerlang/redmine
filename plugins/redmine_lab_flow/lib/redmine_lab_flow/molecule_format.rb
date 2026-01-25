# frozen_string_literal: true

module RedmineLabFlow
  class MoleculeFormat < Redmine::FieldFormat::Base
    add 'molecule'
    self.searchable_supported = true
    self.form_partial = 'custom_fields/formats/molecule'

    def label
      'label_molecule_format'
    end

    def cast_single_value(custom_field, value, customized = nil)
      value.to_s.strip
    end

    def validate_single_value(custom_field, value, customized = nil)
      errs = super
      return errs if value.blank?

      unless MoleculeService.valid_smiles?(value)
        errs << ::I18n.t('activerecord.errors.messages.invalid_smiles')
      end

      errs
    end

    def formatted_value(view, custom_field, value, customized = nil, html = false)
      return '' if value.blank?

      if html
        molecule_html(view, value, custom_field)
      else
        value
      end
    end

    def edit_tag(view, tag_id, tag_name, custom_value, options = {})
      value = custom_value.value || ''

      view.content_tag(:div, class: 'molecule-input-container') do
        view.text_field_tag(tag_name, value, options.merge(
          id: tag_id,
          class: 'molecule-smiles-input',
          placeholder: 'Enter SMILES (e.g., CCO for ethanol)',
          'data-molecule-input' => true
        )) +
        view.content_tag(:div, '', class: 'molecule-preview', id: "#{tag_id}_preview") +
        view.link_to(
          I18n.t('label_molecule_editor'),
          '#',
          class: 'molecule-editor-link icon icon-edit',
          'data-field-id' => tag_id,
          'data-editor-url' => view.url_for(controller: 'lab_flow_molecules', action: 'editor', field_id: tag_id, smiles: value)
        )
      end
    end

    def bulk_edit_tag(view, tag_id, tag_name, custom_field, objects, value, options = {})
      view.text_field_tag(tag_name, value, options.merge(
        id: tag_id,
        class: 'molecule-smiles-input',
        placeholder: 'Enter SMILES'
      ))
    end

    def query_filter_options(custom_field, query)
      { type: :text }
    end

    private

    def molecule_html(view, smiles, custom_field)
      cache = LabFlowMoleculeCache.for_smiles(smiles)

      view.content_tag(:div, class: 'molecule-viewer', 'data-smiles' => smiles) do
        content = view.content_tag(:div, class: 'molecule-structure') do
          if cache&.svg_2d.present?
            cache.svg_2d.html_safe
          else
            # Placeholder that will be rendered by RDKit.js
            view.content_tag(:div, '',
              class: 'molecule-placeholder',
              'data-smiles' => smiles,
              'data-render' => 'rdkit'
            )
          end
        end

        content += view.content_tag(:div, class: 'molecule-info') do
          info = view.content_tag(:span, smiles, class: 'molecule-smiles', title: 'SMILES')

          if cache&.molecular_formula.present?
            info += view.content_tag(:span, cache.molecular_formula, class: 'molecule-formula', title: 'Molecular Formula')
          end

          if cache&.molecular_weight.present?
            info += view.content_tag(:span, "MW: #{cache.molecular_weight.round(2)}", class: 'molecule-weight', title: 'Molecular Weight')
          end

          info
        end

        content += view.link_to(
          I18n.t('label_molecule_properties'),
          view.url_for(controller: 'lab_flow_molecules', action: 'properties', smiles: smiles),
          class: 'molecule-properties-link',
          target: '_blank'
        )

        content
      end
    end
  end
end
