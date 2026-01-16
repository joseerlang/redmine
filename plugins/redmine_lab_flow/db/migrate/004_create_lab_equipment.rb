# frozen_string_literal: true

class CreateLabEquipment < ActiveRecord::Migration[7.0]
  def change
    create_table :lab_equipment do |t|
      t.string :name, null: false
      t.string :serial_number
      t.string :model
      t.string :manufacturer
      t.date :calibration_due
      t.date :last_calibration
      t.string :location
      t.string :status, default: 'available'
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :lab_equipment, :serial_number, unique: true
    add_index :lab_equipment, :calibration_due
    add_index :lab_equipment, :active
    add_index :lab_equipment, :status
  end
end
