# frozen_string_literal: true

class CreateLabFlowSequenceAnnotations < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_sequence_annotations do |t|
      t.references :sequence, null: false, foreign_key: { to_table: :lab_flow_sequences }
      t.string :name, null: false
      t.string :annotation_type, null: false # gene, promoter, primer, restriction_site, cds, terminator, origin
      t.integer :start_position, null: false
      t.integer :end_position, null: false
      t.integer :strand, default: 1 # +1, -1, 0 (none)
      t.string :color
      t.text :notes

      t.timestamps
    end

    add_index :lab_flow_sequence_annotations, :annotation_type
    add_index :lab_flow_sequence_annotations, [:sequence_id, :start_position, :end_position], name: 'idx_seq_annotations_position'
  end
end
