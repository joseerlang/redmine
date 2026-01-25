# frozen_string_literal: true

class CreateLabFlowReportTemplates < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_report_templates do |t|
      t.string :name, null: false
      t.text :description
      t.string :report_type, null: false # experiment, sample_batch, assay_summary, compliance
      t.references :tracker, foreign_key: true
      t.text :template_content # Liquid template
      t.boolean :include_eln_narrative, default: true
      t.boolean :include_signatures, default: false
      t.text :fields_to_include # JSON array of custom field names
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :lab_flow_report_templates, :report_type
    add_index :lab_flow_report_templates, :active
  end
end
