# frozen_string_literal: true

class CreateLabFlowExternalSystems < ActiveRecord::Migration[6.1]
  def change
    create_table :lab_flow_external_systems do |t|
      t.string :name, null: false
      t.string :system_type, null: false # galaxy, openbis, custom
      t.string :base_url, null: false
      t.text :api_key_encrypted
      t.text :api_secret_encrypted
      t.string :auth_type, default: 'api_key' # api_key, oauth2, basic
      t.string :health_check_url
      t.string :last_health_status # ok, error, unknown
      t.datetime :last_health_check_at
      t.text :configuration # JSON for system-specific settings
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :lab_flow_external_systems, :system_type
    add_index :lab_flow_external_systems, :active
  end
end
