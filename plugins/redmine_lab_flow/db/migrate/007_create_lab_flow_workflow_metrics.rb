# frozen_string_literal: true

class CreateLabFlowWorkflowMetrics < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_workflow_metrics do |t|
      t.references :project, null: false, foreign_key: true
      t.references :tracker, null: false, foreign_key: true
      t.references :status, null: false, foreign_key: { to_table: :issue_statuses }
      t.date :date, null: false
      t.integer :count, default: 0, null: false
      t.decimal :avg_time_in_status_hours, precision: 10, scale: 2

      t.timestamps
    end

    add_index :lab_flow_workflow_metrics, [:project_id, :date]
    add_index :lab_flow_workflow_metrics, [:tracker_id, :status_id, :date], name: 'idx_workflow_metrics_tracker_status_date'
    add_index :lab_flow_workflow_metrics, [:project_id, :tracker_id, :date], name: 'idx_workflow_metrics_project_tracker_date', unique: true
  end
end
