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
  post 'job_callback', to: 'lab_flow_external_jobs#callback', as: 'lab_flow_api_job_callback'
end

# ==========================================
# Phase 5.1: Dashboard & Metrics
# ==========================================
scope 'projects/:project_id/lab_flow' do
  get 'dashboard', to: 'lab_flow_dashboard#index', as: 'lab_flow_dashboard'
  get 'metrics', to: 'lab_flow_dashboard#metrics', as: 'lab_flow_metrics', defaults: { format: :json }
  get 'starvation', to: 'lab_flow_dashboard#starvation', as: 'lab_flow_starvation', defaults: { format: :json }
  get 'bottlenecks', to: 'lab_flow_dashboard#bottlenecks', as: 'lab_flow_bottlenecks', defaults: { format: :json }
end

# ==========================================
# Phase 5.2: Reports
# ==========================================
resources :lab_flow_report_templates, except: [:show]

scope 'projects/:project_id' do
  post 'lab_flow_reports/generate', to: 'lab_flow_reports#generate', as: 'lab_flow_generate_report'
  get 'lab_flow_reports/history', to: 'lab_flow_reports#history', as: 'lab_flow_reports_history'
  get 'lab_flow_reports/download/:id', to: 'lab_flow_reports#download', as: 'lab_flow_report_download'
end

# ==========================================
# Phase 5.3: External Systems & Webhooks
# ==========================================
resources :lab_flow_external_systems do
  member do
    post :health_check
  end
end

scope 'projects/:project_id' do
  resources :lab_flow_webhooks do
    member do
      post :test
    end
  end
end

resources :issues, only: [] do
  resources :lab_flow_external_jobs, only: [:index, :create, :show] do
    member do
      post :cancel
    end
  end
end

# ==========================================
# Phase 5.4: FAIR Metadata
# ==========================================
resources :issues, only: [] do
  resource :lab_flow_fair, controller: 'lab_flow_fair', only: [:show, :update] do
    post :mint_doi
    get :export
  end
end

get 'lab_flow_fair/ontology_search', to: 'lab_flow_fair#ontology_search', as: 'lab_flow_ontology_search'

# ==========================================
# Phase 6.1: Molecules
# ==========================================
scope 'lab_flow_molecules' do
  get 'render', to: 'lab_flow_molecules#render_svg', as: 'lab_flow_molecules_render'
  post 'convert', to: 'lab_flow_molecules#convert', as: 'lab_flow_molecules_convert'
  post 'search', to: 'lab_flow_molecules#search', as: 'lab_flow_molecules_search'
  get 'editor', to: 'lab_flow_molecules#editor', as: 'lab_flow_molecules_editor'
  get 'properties', to: 'lab_flow_molecules#properties', as: 'lab_flow_molecules_properties'
end

# ==========================================
# Phase 6.2: Sequences
# ==========================================
resources :issues, only: [] do
  resources :lab_flow_sequences do
    member do
      get :export
      post :restriction_map
    end
    resources :annotations, controller: 'lab_flow_sequence_annotations', only: [:create, :update, :destroy]
  end
end

# ==========================================
# Phase 6.3: Consolidated View
# ==========================================
resources :issues, only: [] do
  resource :consolidated_view, controller: 'lab_flow_consolidated_view', only: [:show] do
    get :timeline
    get :compare
    get :export_history
  end
end
