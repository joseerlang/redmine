# frozen_string_literal: true

class CreateProcedureTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :lab_flow_procedure_templates do |t|
      t.string :name, null: false
      t.text :description
      t.text :content, null: false
      t.boolean :active, default: true, null: false
      t.integer :position

      t.timestamps
    end

    add_index :lab_flow_procedure_templates, :name, unique: true
    add_index :lab_flow_procedure_templates, :active
  end
end
