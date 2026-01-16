# frozen_string_literal: true

class CreateLabReagents < ActiveRecord::Migration[7.0]
  def change
    create_table :lab_reagents do |t|
      t.string :name, null: false
      t.string :lot_number, null: false
      t.date :expiration_date
      t.decimal :quantity, precision: 10, scale: 2
      t.string :unit
      t.string :supplier
      t.string :catalog_number
      t.string :storage_conditions
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :lab_reagents, :lot_number, unique: true
    add_index :lab_reagents, :expiration_date
    add_index :lab_reagents, :active
  end
end
