# frozen_string_literal: true

class CreateLabFlowPropertySnapshots < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_property_snapshots do |t|
      t.references :issue, null: false, foreign_key: true
      t.references :journal, foreign_key: true
      t.text :snapshot_data, null: false # JSON of all properties at this point
      t.string :molecule_smiles
      t.references :sequence, foreign_key: { to_table: :lab_flow_sequences }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :trigger_event # status_change, custom_field_update, manual

      t.timestamps
    end

    add_index :lab_flow_property_snapshots, [:issue_id, :created_at]
    add_index :lab_flow_property_snapshots, :trigger_event
  end
end
