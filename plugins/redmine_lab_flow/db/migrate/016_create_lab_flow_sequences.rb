# frozen_string_literal: true

class CreateLabFlowSequences < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_sequences do |t|
      t.references :issue, null: false, foreign_key: true
      t.string :name, null: false
      t.string :sequence_type, null: false # dna, rna, protein, plasmid
      t.text :sequence_data, null: false
      t.string :format, default: 'raw' # raw, fasta, genbank
      t.integer :length
      t.boolean :circular, default: false
      t.text :metadata # JSON for additional info

      t.timestamps
    end

    add_index :lab_flow_sequences, :sequence_type
    add_index :lab_flow_sequences, [:issue_id, :name]
  end
end
