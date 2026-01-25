# frozen_string_literal: true

class CreateLabFlowFairMetadata < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_fair_metadata do |t|
      t.references :issue, null: false, foreign_key: true, index: { unique: true }
      t.string :doi
      t.string :orcid_creator
      t.string :license, default: 'CC-BY-4.0' # CC-BY-4.0, CC0, CC-BY-NC-4.0, etc.
      t.text :keywords # JSON array
      t.text :ontology_mappings # JSON
      t.string :schema_org_type, default: 'Dataset'
      t.string :access_rights, default: 'open' # open, restricted, embargoed
      t.date :embargo_until
      t.string :funding_reference
      t.text :related_identifiers # JSON array of related DOIs, URLs

      t.timestamps
    end

    add_index :lab_flow_fair_metadata, :doi, unique: true, where: 'doi IS NOT NULL'
    add_index :lab_flow_fair_metadata, :access_rights
  end
end
