# frozen_string_literal: true

class CreateLabFlowOntologyTerms < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_ontology_terms do |t|
      t.string :ontology, null: false # OBI, CHEBI, NCIT, EFO, GO, SO
      t.string :term_id, null: false
      t.string :label, null: false
      t.text :definition
      t.string :iri
      t.references :parent_term, foreign_key: { to_table: :lab_flow_ontology_terms }
      t.references :custom_field, foreign_key: true

      t.timestamps
    end

    add_index :lab_flow_ontology_terms, [:ontology, :term_id], unique: true
    add_index :lab_flow_ontology_terms, :label
    add_index :lab_flow_ontology_terms, :iri
  end
end
