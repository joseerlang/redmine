# frozen_string_literal: true

class CreateLabFlowMoleculeCaches < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_molecule_caches do |t|
      t.string :smiles, null: false
      t.string :inchi
      t.string :inchi_key
      t.text :mol_block
      t.text :svg_2d # Cached SVG rendering
      t.string :molecular_formula
      t.decimal :molecular_weight, precision: 12, scale: 4
      t.text :properties # JSON: LogP, TPSA, HBD, HBA, etc.

      t.timestamps
    end

    add_index :lab_flow_molecule_caches, :smiles, unique: true
    add_index :lab_flow_molecule_caches, :inchi_key, unique: true, where: 'inchi_key IS NOT NULL'
  end
end
