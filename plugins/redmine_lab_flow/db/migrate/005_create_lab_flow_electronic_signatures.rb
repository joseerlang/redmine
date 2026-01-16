# frozen_string_literal: true

class CreateLabFlowElectronicSignatures < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_electronic_signatures do |t|
      t.references :issue, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :signature_meaning, null: false
      t.string :source_ip
      t.string :old_status
      t.string :new_status
      t.datetime :signed_at, null: false

      t.timestamps
    end

    add_index :lab_flow_electronic_signatures, [:issue_id, :signed_at]
    add_index :lab_flow_electronic_signatures, :signature_meaning
  end
end
