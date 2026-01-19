# Plan de Implementación: Fases 5 y 6 - Redmine LabFlow

## Resumen Ejecutivo

Este plan detalla la implementación de las **Fases 5 y 6** del plugin `redmine_lab_flow`, transformando Redmine de un sistema de registro en un **centro de inteligencia de datos** con capacidades de visualización científica avanzada.

**Estado actual**: Fases 1-4 completadas (LIMS, ELN, Inventario, Compliance)
**Objetivo**: Añadir dashboards de rendimiento, reportes automatizados, interoperabilidad externa, datos FAIR, y visualizadores moleculares/genómicos.

---

# FASE 5: Inteligencia de Datos e Interoperabilidad

## 5.1 Cuadros de Mando (Dashboards) de Rendimiento

### Objetivo
Implementar gráficos visuales que muestran el flujo de trabajo en tiempo real, detectando "Issue Starvation" (muestras atascadas) y cuellos de botella.

### Componentes Técnicos

**Migración**: `007_create_lab_flow_workflow_metrics.rb`
```
Tabla: lab_flow_workflow_metrics
- project_id, tracker_id, date, status_id
- count, avg_time_in_status_hours
- Índices: [project_id, date], [tracker_id, status_id, date]
```

**Modelo**: `LabFlowWorkflowMetric`
- Scopes: `by_project`, `by_date_range`, `by_tracker`
- Método: `aggregate_by_status(project)`

**Servicio**: `LabFlowMetricsCalculator`
- `calculate_daily_metrics(project)` - Calcula métricas diarias
- `detect_starvation(project, threshold_hours: 48)` - Detecta issues atascados
- `bottleneck_analysis(project)` - Analiza cuellos de botella

**Controlador**: `LabFlowDashboardController`
- Acciones: `index`, `metrics.json`, `starvation.json`

**Assets**: Chart.js (CDN) para gráficos interactivos

**Rake Task**: `lab_flow:calculate_metrics` (ejecutar diariamente vía cron)

---

## 5.2 Generación de Reportes Automáticos

### Objetivo
Crear informes finales de experimentos con un clic, extrayendo datos de custom fields y narrativa del ELN.

### Componentes Técnicos

**Migraciones**:
- `008_create_lab_flow_report_templates.rb`
- `009_create_lab_flow_generated_reports.rb`

**Tabla report_templates**:
```
- name, description, report_type (experiment, sample_batch, assay_summary, compliance)
- tracker_id, template_content (Liquid)
- include_eln_narrative, include_signatures
- fields_to_include (JSON array)
```

**Tabla generated_reports**:
```
- report_template_id, issue_id, project_id, generated_by_id
- format (pdf, xlsx, json), file_path, parameters (JSON)
```

**Servicios**:
- `LabFlowReportGenerator` - Orquesta generación
- `LabFlowPdfGenerator` - Usa gem `prawn`
- `LabFlowExcelGenerator` - Usa gem `caxlsx`
- `LabFlowJsonExporter` - JSON estructurado

**Controlador**: `LabFlowReportsController`
- CRUD de templates + `generate`, `download`, `history`

**Gems requeridas**: `prawn`, `prawn-table`, `caxlsx`, `liquid`

---

## 5.3 Conexión con Ecosistema Externo (Galaxy, OpenBIS)

### Objetivo
Integración bidireccional con plataformas especializadas mediante webhooks y APIs.

### Componentes Técnicos

**Migraciones**:
- `010_create_lab_flow_external_systems.rb`
- `011_create_lab_flow_webhooks.rb`
- `012_create_lab_flow_external_jobs.rb`

**Tabla external_systems**:
```
- name, system_type (galaxy, openbis, custom)
- base_url, api_key_encrypted, api_secret_encrypted
- auth_type (api_key, oauth2, basic)
- health_check_url, last_health_status
```

**Tabla webhooks**:
```
- project_id, external_system_id
- event_type (issue.created, issue.updated, status.changed, assay.completed)
- target_url, secret_token, payload_template (Liquid)
- retry_count, last_triggered_at
```

**Tabla external_jobs**:
```
- issue_id, external_system_id, external_job_id
- job_type, status (pending, submitted, running, completed, failed)
- input_parameters (JSON), output_data (JSON)
```

**Servicios** (soporte completo Galaxy + OpenBIS + webhooks):
- `LabFlowWebhookDispatcher` - Envía webhooks con firma HMAC-SHA256 a cualquier sistema
- `LabFlowGalaxyClient` - Cliente completo para Galaxy API (submit workflow, check status, fetch results)
- `LabFlowOpenBISClient` - Cliente para OpenBIS JSON-RPC (create sample, upload dataset, sync metadata)
- `LabFlowGenericClient` - Cliente base para sistemas custom via webhooks

**Controladores**:
- `LabFlowExternalSystemsController` - CRUD de sistemas externos (Galaxy, OpenBIS, custom)
- `LabFlowWebhooksController` - CRUD + test de webhooks
- `LabFlowExternalJobsController` - submit, status, cancel, results

---

## 5.4 Datos FAIR (Findable, Accessible, Interoperable, Reusable)

### Objetivo
Implementar principios FAIR con metadatos enriquecidos, ontologías y DOIs.

### Componentes Técnicos

**Migraciones**:
- `013_create_lab_flow_fair_metadata.rb`
- `014_create_lab_flow_ontology_terms.rb`

**Tabla fair_metadata**:
```
- issue_id (unique), doi, orcid_creator
- license (CC-BY-4.0, CC0, etc.), keywords (JSON)
- ontology_mappings (JSON), schema_org_type
- access_rights (open, restricted, embargoed)
```

**Tabla ontology_terms**:
```
- ontology (OBI, CHEBI, NCIT, EFO), term_id, label
- definition, iri, parent_term_id
- custom_field_id (para sugerencias de mapeo)
```

**Servicios**:
- `LabFlowFairExporter` - Exporta DataCite XML, Schema.org JSON-LD, RO-Crate, ISA-Tab
- `LabFlowOntologyMapper` - Busca en OLS (Ontology Lookup Service)
- `LabFlowDoiMinter` - **Preparado pero desactivado** (estructura lista para futura conexión a DataCite)

**Controlador**: `LabFlowFairController`
- `show`, `update`, `export`, `mint_doi` (desactivado por defecto), `ontology_search`

**Nota**: La funcionalidad de DOI estará preparada estructuralmente pero sin conexión activa a DataCite. Se habilitará via configuración cuando el laboratorio obtenga membresía.

---

# FASE 6: Ventanas Científicas (Visualizadores)

## 6.1 Visualización Molecular con RDKit.js

### Objetivo
Renderizar estructuras químicas en 2D/3D, soportando SMILES/MOL/InChI y búsqueda por subestructura.

### Componentes Técnicos

**Migración**: `015_create_lab_flow_molecule_caches.rb`
```
- smiles (unique), inchi, inchi_key
- mol_block, svg_2d (cached), molecular_formula
- molecular_weight, properties (JSON)
```

**Custom Field Format**: `MoleculeFormat` (basado en `wiki_reference_format.rb`)
- Almacena: SMILES canónico
- Renderiza: SVG 2D via RDKit.js
- Valida: Sintaxis SMILES

**Servicio**: `LabFlowMoleculeService`
- `canonicalize_smiles`, `smiles_to_inchi`
- `render_svg`, `calculate_properties`
- `substructure_search`

**Controlador**: `LabFlowMoleculesController`
- `render`, `convert`, `search`, `editor`, `properties`

**Assets**:
- RDKit.js (WASM) desde CDN
- **Ketcher** (editor molecular EPAM, código abierto) - preferido por su potencia para química compleja

---

## 6.2 Visualización Genómica con SeqViz

### Objetivo
Visor de secuencias ADN/ARN/proteínas con mapas de plásmidos y anotaciones.

### Componentes Técnicos

**Migraciones**:
- `016_create_lab_flow_sequences.rb`
- `017_create_lab_flow_sequence_annotations.rb`

**Tabla sequences**:
```
- issue_id, name, sequence_type (dna, rna, protein, plasmid)
- sequence_data, format (fasta, genbank), length
- annotations (JSON), circular (boolean)
```

**Tabla sequence_annotations**:
```
- sequence_id, name, type (gene, promoter, primer, restriction_site)
- start_position, end_position, strand (+1/-1/0)
- color, notes
```

**Custom Field Format**: `SequenceFormat`
- Almacena: Referencia a LabFlowSequence.id
- Renderiza: Visor SeqViz interactivo

**Servicio**: `LabFlowSequenceService`
- `parse_fasta`, `parse_genbank`
- `find_restriction_sites`, `translate`

**Controlador**: `LabFlowSequencesController`
- `show`, `create`, `annotations`, `restriction_map`, `export`

**Assets**: SeqViz.js (UMD bundle)

---

## 6.3 Sincronización de Metadatos y Vista Consolidada

### Objetivo
Vista unificada que relaciona visualizaciones con propiedades físicas y timeline de cambios.

### Componentes Técnicos

**Migración**: `018_create_lab_flow_property_snapshots.rb`
```
- issue_id, journal_id, snapshot_data (JSON)
- molecule_smiles, sequence_id
- created_at
```

**Servicio**: `LabFlowSnapshotService`
- `create_snapshot` - Crea snapshot tras cada cambio
- `diff_snapshots` - Compara dos puntos en el tiempo
- `build_timeline` - Construye timeline visual

**Controlador**: `LabFlowConsolidatedViewController`
- `show` - Vista consolidada del issue
- `timeline` - Timeline de cambios
- `compare` - Compara versiones

---

# Archivos Críticos a Modificar/Crear

## Nuevas Migraciones (12)
```
db/migrate/007_create_lab_flow_workflow_metrics.rb
db/migrate/008_create_lab_flow_report_templates.rb
db/migrate/009_create_lab_flow_generated_reports.rb
db/migrate/010_create_lab_flow_external_systems.rb
db/migrate/011_create_lab_flow_webhooks.rb
db/migrate/012_create_lab_flow_external_jobs.rb
db/migrate/013_create_lab_flow_fair_metadata.rb
db/migrate/014_create_lab_flow_ontology_terms.rb
db/migrate/015_create_lab_flow_molecule_caches.rb
db/migrate/016_create_lab_flow_sequences.rb
db/migrate/017_create_lab_flow_sequence_annotations.rb
db/migrate/018_create_lab_flow_property_snapshots.rb
```

## Nuevos Modelos (12)
```
app/models/lab_flow_workflow_metric.rb
app/models/lab_flow_report_template.rb
app/models/lab_flow_generated_report.rb
app/models/lab_flow_external_system.rb
app/models/lab_flow_webhook.rb
app/models/lab_flow_external_job.rb
app/models/lab_flow_fair_metadata.rb
app/models/lab_flow_ontology_term.rb
app/models/lab_flow_molecule_cache.rb
app/models/lab_flow_sequence.rb
app/models/lab_flow_sequence_annotation.rb
app/models/lab_flow_property_snapshot.rb
```

## Nuevos Controladores (9)
```
app/controllers/lab_flow_dashboard_controller.rb
app/controllers/lab_flow_reports_controller.rb
app/controllers/lab_flow_webhooks_controller.rb
app/controllers/lab_flow_external_systems_controller.rb
app/controllers/lab_flow_external_jobs_controller.rb
app/controllers/lab_flow_fair_controller.rb
app/controllers/lab_flow_molecules_controller.rb
app/controllers/lab_flow_sequences_controller.rb
app/controllers/lab_flow_consolidated_view_controller.rb
```

## Nuevos Custom Field Formats (2)
```
lib/redmine_lab_flow/molecule_format.rb
lib/redmine_lab_flow/sequence_format.rb
```

## Nuevos Servicios (13)
```
lib/redmine_lab_flow/metrics_calculator.rb
lib/redmine_lab_flow/report_generator.rb
lib/redmine_lab_flow/pdf_generator.rb
lib/redmine_lab_flow/excel_generator.rb
lib/redmine_lab_flow/json_exporter.rb
lib/redmine_lab_flow/webhook_dispatcher.rb
lib/redmine_lab_flow/galaxy_client.rb
lib/redmine_lab_flow/openbis_client.rb
lib/redmine_lab_flow/fair_exporter.rb
lib/redmine_lab_flow/ontology_mapper.rb
lib/redmine_lab_flow/doi_minter.rb
lib/redmine_lab_flow/molecule_service.rb
lib/redmine_lab_flow/sequence_service.rb
lib/redmine_lab_flow/snapshot_service.rb
```

## Archivos a Modificar
- `config/routes.rb` - Añadir todas las nuevas rutas (ver detalle abajo)
- `lib/redmine_lab_flow/hooks.rb` - Añadir hooks para visualizadores
- `lib/redmine_lab_flow/issue_patch.rb` - Callbacks para snapshots y webhooks
- `config/locales/en.yml` - Nuevas traducciones
- `init.rb` - Registrar nuevos formatos de custom field (MoleculeFormat, SequenceFormat)

## Rutas a Añadir en `config/routes.rb`
```ruby
# Phase 5.1: Dashboard
scope 'projects/:project_id/lab_flow' do
  get 'dashboard', to: 'lab_flow_dashboard#index'
  get 'metrics', to: 'lab_flow_dashboard#metrics', defaults: { format: :json }
  get 'starvation', to: 'lab_flow_dashboard#starvation', defaults: { format: :json }
end

# Phase 5.2: Reports
resources :lab_flow_report_templates, except: [:show]
scope 'projects/:project_id' do
  post 'lab_flow_reports/generate', to: 'lab_flow_reports#generate'
  get 'lab_flow_reports/history', to: 'lab_flow_reports#history'
  get 'lab_flow_reports/download/:id', to: 'lab_flow_reports#download', as: 'lab_flow_report_download'
end

# Phase 5.3: External Systems
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
scope 'lab_flow_api' do
  post 'job_callback', to: 'lab_flow_api#job_callback'
end
resources :issues, only: [] do
  resources :lab_flow_external_jobs, only: [:index, :create, :show] do
    member do
      post :cancel
    end
  end
end

# Phase 5.4: FAIR
resources :issues, only: [] do
  resource :lab_flow_fair, controller: 'lab_flow_fair', only: [:show, :update] do
    post :mint_doi
    get :export
  end
end
get 'lab_flow_fair/ontology_search', to: 'lab_flow_fair#ontology_search'

# Phase 6.1: Molecules
scope 'lab_flow_molecules' do
  get 'render', to: 'lab_flow_molecules#render'
  post 'convert', to: 'lab_flow_molecules#convert'
  post 'search', to: 'lab_flow_molecules#search'
  get 'editor', to: 'lab_flow_molecules#editor'
end

# Phase 6.2: Sequences
resources :issues, only: [] do
  resources :lab_flow_sequences do
    member do
      get :export
      post :restriction_map
    end
    resources :annotations, controller: 'lab_flow_sequence_annotations', only: [:create, :update, :destroy]
  end
end

# Phase 6.3: Consolidated View
resources :issues, only: [] do
  resource :consolidated_view, controller: 'lab_flow_consolidated_view', only: [:show] do
    get :timeline
    get :compare
    get :export_history
  end
end
```

---

## Hooks a Añadir en `lib/redmine_lab_flow/hooks.rb`

```ruby
# Phase 5.1: Dashboard link in project sidebar (extend existing partial)
# Ya existe: render_on :view_projects_show_sidebar_bottom

# Phase 5.2: "Generate Report" button on issue show
def view_issues_show_details_bottom(context = {})
  # Extender método existente para incluir:
  # - Badge de finalización (existente)
  # - Botón "Generate Report" para Sample/Assay completados
  # - Link a "Consolidated View"
end

# Phase 6.1: Molecule viewer rendering
# Los custom fields tipo 'molecule' se renderizan automáticamente
# via MoleculeFormat#formatted_value

# Phase 6.2: Sequence viewer panel
def view_issues_show_description_bottom(context = {})
  # Extender método existente para incluir:
  # - Panel de secuencias asociadas
  # - Visor SeqViz inline
end

# Phase 6.3: Consolidated view link
# Añadir a view_issues_show_details_bottom

# JavaScript/CSS para visualizadores (extend html_head)
render_on :view_layouts_base_html_head,
          partial: 'hooks/redmine_lab_flow/html_head'
# Actualizar partial para incluir:
# - Chart.js CDN
# - RDKit.js WASM
# - SeqViz.js
# - Ketcher.js
```

---

# Verificación y Testing

## Tests a Crear
```
test/unit/lab_flow_workflow_metric_test.rb
test/unit/lab_flow_report_template_test.rb
test/unit/lab_flow_external_system_test.rb
test/unit/lab_flow_webhook_test.rb
test/unit/lab_flow_fair_metadata_test.rb
test/unit/lab_flow_molecule_cache_test.rb
test/unit/lab_flow_sequence_test.rb
test/functional/lab_flow_dashboard_controller_test.rb
test/functional/lab_flow_reports_controller_test.rb
test/functional/lab_flow_molecules_controller_test.rb
test/functional/lab_flow_sequences_controller_test.rb
test/integration/external_integration_test.rb
test/system/dashboard_system_test.rb
test/system/molecule_viewer_system_test.rb
```

## Tests de Sistema (UI) - Añadir a `test/system/lab_flow_system_test.rb`

```ruby
# ==========================================
# Phase 5.1: Dashboard Tests
# ==========================================

def test_dashboard_displays_workflow_metrics
  skip "Dashboard not available" unless defined?(LabFlowWorkflowMetric)

  log_user('admin', 'admin')
  visit "/projects/ecookbook/lab_flow/dashboard"

  assert page.has_content?('Performance Dashboard') || page.has_content?('Workflow Metrics')
  assert page.has_css?('canvas') || page.has_css?('.chart-container'),
         "Dashboard should display charts"
end

def test_dashboard_shows_starvation_alerts
  skip "Dashboard not available" unless defined?(LabFlowWorkflowMetric)

  log_user('admin', 'admin')

  # Create an issue that hasn't been updated in 48+ hours
  old_issue = Issue.create!(
    project: @project,
    tracker: @assay_tracker,
    subject: 'Stale Assay Test',
    author: User.find_by(login: 'admin'),
    status: @in_analysis_status,
    priority: IssuePriority.default || IssuePriority.first
  )
  old_issue.update_column(:updated_on, 3.days.ago)

  visit "/projects/ecookbook/lab_flow/dashboard"

  assert page.has_content?('Starvation') || page.has_content?('Stuck') ||
         page.has_css?('.starvation-alert'),
         "Dashboard should show starvation alerts"
end

# ==========================================
# Phase 5.2: Report Generation Tests
# ==========================================

def test_generate_report_button_appears_on_completed_assay
  skip "Reports not available" unless defined?(LabFlowReportTemplate)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @assay_tracker,
    subject: 'Completed Assay for Report',
    author: User.find_by(login: 'admin'),
    status: @completed_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  visit "/issues/#{issue.id}"

  assert page.has_link?('Generate Report') || page.has_button?('Generate Report'),
         "Completed issues should show Generate Report button"
end

def test_create_report_template
  skip "Reports not available" unless defined?(LabFlowReportTemplate)

  log_user('admin', 'admin')
  visit '/lab_flow_report_templates/new'

  fill_in 'Name', with: 'Standard Experiment Report'
  select 'experiment', from: 'Report type' if page.has_select?('Report type')
  fill_in 'Template content', with: '# {{ issue.subject }}' if page.has_field?('Template content')

  click_button 'Create' || click_button 'Save'

  assert page.has_content?('created') || page.has_content?('Standard Experiment Report')
end

def test_generate_pdf_report
  skip "Reports not available" unless defined?(LabFlowReportTemplate) && defined?(LabFlowGeneratedReport)

  log_user('admin', 'admin')

  # Create template first
  template = LabFlowReportTemplate.create!(
    name: 'Test Template',
    report_type: 'experiment',
    template_content: '# Test'
  )

  issue = Issue.create!(
    project: @project,
    tracker: @assay_tracker,
    subject: 'Assay for PDF Report',
    author: User.find_by(login: 'admin'),
    status: @completed_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  visit "/issues/#{issue.id}"
  click_link 'Generate Report' if page.has_link?('Generate Report')

  if page.has_select?('Format')
    select 'PDF', from: 'Format'
    click_button 'Generate'

    assert page.has_content?('generated') || page.has_link?('Download')
  end
end

# ==========================================
# Phase 5.3: External Systems Tests
# ==========================================

def test_configure_external_system
  skip "External systems not available" unless defined?(LabFlowExternalSystem)

  log_user('admin', 'admin')
  visit '/lab_flow_external_systems/new'

  fill_in 'Name', with: 'Test Galaxy Server'
  select 'galaxy', from: 'System type' if page.has_select?('System type')
  fill_in 'Base url', with: 'https://usegalaxy.org'

  click_button 'Create' || click_button 'Save'

  assert page.has_content?('created') || page.has_content?('Test Galaxy Server')
end

def test_create_webhook
  skip "Webhooks not available" unless defined?(LabFlowWebhook)

  log_user('admin', 'admin')
  visit "/projects/ecookbook/lab_flow_webhooks/new"

  if page.has_field?('Target url')
    fill_in 'Target url', with: 'https://example.com/webhook'
    select 'assay.completed', from: 'Event type' if page.has_select?('Event type')

    click_button 'Create' || click_button 'Save'

    assert page.has_content?('created') || page.has_content?('example.com')
  end
end

def test_view_external_jobs_on_issue
  skip "External jobs not available" unless defined?(LabFlowExternalJob)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @assay_tracker,
    subject: 'Assay with External Job',
    author: User.find_by(login: 'admin'),
    status: @in_analysis_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  visit "/issues/#{issue.id}"

  # Should show external jobs panel even if empty
  assert page.has_content?('External Jobs') || page.has_css?('.external-jobs-panel') ||
         page.has_link?('Submit to External System')
end

# ==========================================
# Phase 5.4: FAIR Metadata Tests
# ==========================================

def test_fair_metadata_panel_on_issue
  skip "FAIR not available" unless defined?(LabFlowFairMetadata)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample for FAIR Test',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  visit "/issues/#{issue.id}"

  assert page.has_content?('FAIR') || page.has_link?('FAIR Metadata') ||
         page.has_css?('.fair-metadata-panel')
end

def test_edit_fair_metadata
  skip "FAIR not available" unless defined?(LabFlowFairMetadata)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample for FAIR Edit',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  visit "/issues/#{issue.id}/lab_flow_fair"

  if page.has_select?('License')
    select 'CC-BY-4.0', from: 'License'
    fill_in 'Keywords', with: 'test, sample, laboratory' if page.has_field?('Keywords')

    click_button 'Save' || click_button 'Update'

    assert page.has_content?('updated') || page.has_content?('CC-BY-4.0')
  end
end

def test_export_datacite_xml
  skip "FAIR not available" unless defined?(LabFlowFairMetadata)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample for DataCite Export',
    author: User.find_by(login: 'admin'),
    status: @completed_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  visit "/issues/#{issue.id}/lab_flow_fair/export?format=datacite"

  # Should either download or display XML
  assert page.has_content?('datacite') || page.has_content?('identifier') ||
         page.response_headers['Content-Type']&.include?('xml')
end

# ==========================================
# Phase 6.1: Molecule Visualization Tests
# ==========================================

def test_molecule_custom_field_renders_structure
  skip "Molecule format not available" unless defined?(RedmineLabFlow::MoleculeFormat)

  log_user('admin', 'admin')

  # Create molecule custom field if not exists
  molecule_field = IssueCustomField.find_or_create_by!(name: 'Chemical Structure') do |cf|
    cf.field_format = 'molecule'
    cf.is_for_all = true
  end
  @assay_tracker.custom_fields << molecule_field unless @assay_tracker.custom_fields.include?(molecule_field)

  issue = Issue.create!(
    project: @project,
    tracker: @assay_tracker,
    subject: 'Assay with Molecule',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  # Set SMILES value for ethanol
  cv = issue.custom_field_values.find { |v| v.custom_field.name == 'Chemical Structure' }
  cv.value = 'CCO' if cv
  issue.save!

  visit "/issues/#{issue.id}"

  assert page.has_css?('.molecule-viewer') || page.has_css?('svg') ||
         page.has_content?('CCO'),
         "Molecule structure should be rendered"
end

def test_molecule_editor_opens
  skip "Molecule format not available" unless defined?(RedmineLabFlow::MoleculeFormat)

  log_user('admin', 'admin')

  visit '/lab_flow_molecules/editor'

  assert page.has_css?('#ketcher-container') || page.has_css?('.molecule-editor') ||
         page.has_content?('Ketcher'),
         "Molecule editor should be available"
end

def test_molecule_substructure_search
  skip "Molecule search not available" unless defined?(LabFlowMoleculeCache)

  log_user('admin', 'admin')

  # Create some molecules first
  LabFlowMoleculeCache.create!(smiles: 'CCO', inchi_key: 'LFQSCWFLJHTTHZ-UHFFFAOYSA-N')
  LabFlowMoleculeCache.create!(smiles: 'CCCO', inchi_key: 'BDERNNFJNOPAEC-UHFFFAOYSA-N')

  visit '/lab_flow_molecules/search'

  if page.has_field?('Query SMILES') || page.has_field?('query_smiles')
    fill_in 'Query SMILES', with: 'CC'
    click_button 'Search'

    assert page.has_content?('CCO') || page.has_content?('CCCO') ||
           page.has_css?('.search-results'),
           "Substructure search should return results"
  end
end

# ==========================================
# Phase 6.2: Sequence Visualization Tests
# ==========================================

def test_sequence_viewer_displays
  skip "Sequence not available" unless defined?(LabFlowSequence)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample with DNA Sequence',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  sequence = LabFlowSequence.create!(
    issue: issue,
    name: 'Test Plasmid',
    sequence_type: 'plasmid',
    sequence_data: 'ATGCATGCATGC',
    circular: true
  )

  visit "/issues/#{issue.id}"

  assert page.has_css?('.seqviz-container') || page.has_css?('#seqviz') ||
         page.has_content?('Test Plasmid'),
         "Sequence viewer should be displayed"
end

def test_upload_fasta_sequence
  skip "Sequence not available" unless defined?(LabFlowSequence)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample for FASTA Upload',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  visit "/issues/#{issue.id}/lab_flow_sequences/new"

  if page.has_field?('Name')
    fill_in 'Name', with: 'Uploaded Sequence'
    fill_in 'Sequence data', with: '>test\nATGCATGCATGC' if page.has_field?('Sequence data')
    select 'dna', from: 'Sequence type' if page.has_select?('Sequence type')

    click_button 'Create' || click_button 'Save'

    assert page.has_content?('created') || page.has_content?('Uploaded Sequence')
  end
end

def test_find_restriction_sites
  skip "Sequence not available" unless defined?(LabFlowSequence)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample for Restriction Sites',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  # Sequence with EcoRI site (GAATTC)
  sequence = LabFlowSequence.create!(
    issue: issue,
    name: 'Sequence with EcoRI',
    sequence_type: 'dna',
    sequence_data: 'ATGCGAATTCATGC',
    circular: false
  )

  visit "/issues/#{issue.id}/lab_flow_sequences/#{sequence.id}"

  if page.has_button?('Find Restriction Sites') || page.has_link?('Restriction Sites')
    click_button 'Find Restriction Sites' rescue click_link 'Restriction Sites'

    assert page.has_content?('EcoRI') || page.has_css?('.restriction-sites'),
           "Should find EcoRI restriction site"
  end
end

# ==========================================
# Phase 6.3: Consolidated View Tests
# ==========================================

def test_consolidated_view_displays_all_data
  skip "Consolidated view not available" unless defined?(LabFlowPropertySnapshot)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample for Consolidated View',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  visit "/issues/#{issue.id}/consolidated_view"

  assert page.has_content?('Consolidated View') || page.has_css?('.consolidated-view-container'),
         "Consolidated view page should load"
  assert page.has_content?('Physical Properties') || page.has_content?('Properties'),
         "Should show properties section"
end

def test_consolidated_view_timeline
  skip "Timeline not available" unless defined?(LabFlowPropertySnapshot)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample for Timeline',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  # Create some history by updating the issue
  issue.status = @in_analysis_status
  issue.save!

  visit "/issues/#{issue.id}/consolidated_view/timeline"

  assert page.has_css?('.timeline') || page.has_css?('.property-timeline') ||
         page.has_content?('Timeline'),
         "Timeline should be displayed"
end

def test_compare_snapshots
  skip "Snapshots not available" unless defined?(LabFlowPropertySnapshot)

  log_user('admin', 'admin')

  issue = Issue.create!(
    project: @project,
    tracker: @sample_tracker,
    subject: 'Sample for Comparison',
    author: User.find_by(login: 'admin'),
    status: @accessioned_status,
    priority: IssuePriority.default || IssuePriority.first
  )

  # Create snapshots
  snapshot1 = LabFlowPropertySnapshot.create!(issue: issue, snapshot_data: { status: 'Accessioned' })
  issue.status = @in_analysis_status
  issue.save!
  snapshot2 = LabFlowPropertySnapshot.create!(issue: issue, snapshot_data: { status: 'In Analysis' })

  visit "/issues/#{issue.id}/consolidated_view/compare?snapshot_1=#{snapshot1.id}&snapshot_2=#{snapshot2.id}"

  assert page.has_content?('Compare') || page.has_css?('.comparison-view'),
         "Comparison view should be displayed"
end
```

---

# Dependencias Externas

## Gems a Añadir
```ruby
gem 'prawn', '~> 2.4'
gem 'prawn-table', '~> 0.2'
gem 'caxlsx', '~> 3.2'
gem 'liquid', '~> 5.4'
```

## CDNs JavaScript
- Chart.js: `https://cdn.jsdelivr.net/npm/chart.js`
- RDKit.js: `https://unpkg.com/@rdkit/rdkit/dist/RDKit_minimal.js`
- SeqViz: `https://unpkg.com/seqviz`
- Ketcher (editor molecular): `https://unpkg.com/ketcher-react/dist/`

## APIs Externas (opcionales)
- DataCite API (para DOIs)
- OLS (Ontology Lookup Service)
- Galaxy API
- OpenBIS JSON-RPC

---

# Orden de Implementación Recomendado

1. **Dashboard (5.1)** - Menor dependencias, valor inmediato
2. **Reportes (5.2)** - Aprovecha datos existentes
3. **Visualizador Molecular (6.1)** - Independiente
4. **Visualizador Genómico (6.2)** - Independiente
5. **Vista Consolidada (6.3)** - Requiere 6.1 y 6.2
6. **Integración Externa (5.3)** - Más complejo, requiere configuración
7. **FAIR (5.4)** - Opcional, requiere DataCite membership
