# frozen_string_literal: true

# Existing lab flow dashboard route
get 'projects/:project_id/lab_flow', to: 'lab_flow#index', as: 'project_lab_flow'

# Admin procedure templates CRUD
resources :procedure_templates, except: [:show]

# Project-level wiki templates API (JSON)
scope 'projects/:project_id' do
  get 'wiki_templates', to: 'wiki_templates#index', as: 'wiki_templates'
  get 'wiki_templates/:id', to: 'wiki_templates#show', as: 'wiki_template'
end

# Project lab flow settings
patch 'projects/:project_id/lab_flow_settings', to: 'lab_flow_settings#update', as: 'lab_flow_settings'
