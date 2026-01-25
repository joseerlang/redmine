# frozen_string_literal: true

class CreateLabFlowExternalJobs < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_external_jobs do |t|
      t.references :issue, null: false, foreign_key: true
      t.references :external_system, null: false, foreign_key: { to_table: :lab_flow_external_systems }
      t.references :submitted_by, null: false, foreign_key: { to_table: :users }
      t.string :external_job_id
      t.string :job_type # workflow, analysis, data_import
      t.string :status, default: 'pending' # pending, submitted, running, completed, failed, cancelled
      t.text :input_parameters # JSON
      t.text :output_data # JSON
      t.text :error_message
      t.datetime :submitted_at
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :lab_flow_external_jobs, :status
    add_index :lab_flow_external_jobs, :external_job_id
    add_index :lab_flow_external_jobs, [:issue_id, :status]
  end
end
