# frozen_string_literal: true

class CreateLabFlowProjectSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :lab_flow_project_settings do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.boolean :allow_admin_unlock_finalized, default: true, null: false

      t.timestamps
    end
  end
end
