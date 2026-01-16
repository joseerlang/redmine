# frozen_string_literal: true

class CreateLabFlowApiKeys < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_api_keys do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :api_key, null: false
      t.string :description
      t.boolean :active, default: true, null: false
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :lab_flow_api_keys, :api_key, unique: true
    add_index :lab_flow_api_keys, [:project_id, :active]
  end
end
