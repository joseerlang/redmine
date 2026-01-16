# frozen_string_literal: true

# Existing lab flow dashboard route
get 'projects/:project_id/lab_flow', to: 'lab_flow#index', as: 'project_lab_flow'

# Admin procedure templates CRUD
resources :procedure_templates

# Phase 3: Inventory management
resources :lab_reagents
resources :lab_equipment

# Project-level wiki templates API (JSON)
scope 'projects/:project_id' do
  get 'wiki_templates', to: 'wiki_templates#index', as: 'wiki_templates'
  get 'wiki_templates/:id', to: 'wiki_templates#show', as: 'wiki_template'
end

# Project lab flow settings
patch 'projects/:project_id/lab_flow_settings', to: 'lab_flow_settings#update', as: 'lab_flow_settings'

# Issue Wiki integration - create Wiki page from issue
resources :issues, only: [] do
  resources :wiki_pages, controller: 'issue_wiki_pages', only: [:new, :create], as: 'issue_wiki_pages'
end

# Phase 4: Electronic Signatures
scope 'lab_flow' do
  post 'verify_signature', to: 'lab_flow_signatures#verify', as: 'lab_flow_verify_signature'
  get 'signatures/:issue_id', to: 'lab_flow_signatures#index', as: 'lab_flow_issue_signatures'
end

# Phase 4: API Keys Management
resources :lab_flow_api_keys, except: [:edit] do
  member do
    post :regenerate
  end
end

# Phase 4: External API for instrument interoperability
scope 'lab_flow_api' do
  get 'assays/:internal_id', to: 'lab_flow_api#show_assay', as: 'lab_flow_api_show_assay'
  post 'assays/:internal_id', to: 'lab_flow_api#update_assay', as: 'lab_flow_api_update_assay'
  get 'projects/:project_id/assays', to: 'lab_flow_api#list_assays', as: 'lab_flow_api_list_assays'
end
