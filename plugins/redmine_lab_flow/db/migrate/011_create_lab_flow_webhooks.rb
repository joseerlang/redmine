# frozen_string_literal: true

class CreateLabFlowWebhooks < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_webhooks do |t|
      t.references :project, null: false, foreign_key: true
      t.references :external_system, foreign_key: { to_table: :lab_flow_external_systems }
      t.string :event_type, null: false # issue.created, issue.updated, status.changed, assay.completed
      t.string :target_url, null: false
      t.string :secret_token
      t.text :payload_template # Liquid template
      t.integer :retry_count, default: 3
      t.datetime :last_triggered_at
      t.string :last_status # success, failed
      t.text :last_error
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :lab_flow_webhooks, [:project_id, :event_type]
    add_index :lab_flow_webhooks, :active
  end
end
