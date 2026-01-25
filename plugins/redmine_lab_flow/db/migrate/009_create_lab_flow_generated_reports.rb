# frozen_string_literal: true

class CreateLabFlowGeneratedReports < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_generated_reports do |t|
      t.references :report_template, null: false, foreign_key: { to_table: :lab_flow_report_templates }
      t.references :issue, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :generated_by, null: false, foreign_key: { to_table: :users }
      t.string :format, null: false # pdf, xlsx, json
      t.string :file_path
      t.text :parameters # JSON
      t.string :status, default: 'pending' # pending, generating, completed, failed
      t.text :error_message
      t.integer :file_size

      t.timestamps
    end

    add_index :lab_flow_generated_reports, :format
    add_index :lab_flow_generated_reports, :status
    add_index :lab_flow_generated_reports, [:project_id, :created_at]
  end
end
