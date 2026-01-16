# Phase 2: ELN Integration

## Objective

Implement Electronic Lab Notebook (ELN) features with Wiki integration, procedure templates, record finalization for IP protection, and audit compliance.

---

## Components Implemented

### 1. Procedure Templates (Admin UI)

Dedicated administration interface for managing SOP (Standard Operating Procedure) templates.

**Features:**
- Create, edit, delete procedure templates
- Markdown content support
- Active/inactive status
- Position ordering

**Database Table: `lab_flow_procedure_templates`**
| Column | Type | Description |
|--------|------|-------------|
| name | string | Template name (unique) |
| description | text | Template description |
| content | text | Markdown template content |
| active | boolean | Whether template is available |
| position | integer | Display order |

### 2. Procedure Reference Field

Custom field format linking Daily Log issues to versioned Wiki pages.

**Features:**
- Links to specific Wiki page version (immutable reference)
- Dropdown selection of project Wiki pages
- Displays "Page Title (v3)" format
- Links directly to versioned Wiki page

**Value Format:** `"wiki_page_id:version"` (e.g., "42:3")

### 3. Record Finalization (IP Protection)

Immutable record state for intellectual property protection.

**Features:**
- "Finalized" issue status (closed)
- Description and custom fields become read-only
- Project-configurable admin unlock
- Visual badge on finalized issues

**Database Table: `lab_flow_project_settings`**
| Column | Type | Description |
|--------|------|-------------|
| project_id | reference | Project FK |
| allow_admin_unlock_finalized | boolean | Can admins edit finalized records |

### 4. Reason for Change (Audit Compliance)

Mandatory change justification for 21 CFR Part 11 alignment.

**Features:**
- Required "Reason for Change" when editing Daily Logs
- Stored in journal notes (existing Redmine audit system)
- Client-side validation with server fallback
- Info message explaining requirement

### 5. Wiki Template Integration

Template selector when creating new Wiki pages.

**Features:**
- Dropdown to select procedure template
- JavaScript fetches template content via JSON API
- Pre-fills Wiki page content

---

## Files Created

### Database Migrations
- `db/migrate/001_create_procedure_templates.rb`
- `db/migrate/002_create_lab_flow_project_settings.rb`

### Models
- `app/models/lab_flow_procedure_template.rb`
- `app/models/lab_flow_project_setting.rb`

### Custom Field Format
- `lib/redmine_lab_flow/wiki_reference_format.rb`
- `app/views/custom_fields/formats/_wiki_reference.html.erb`

### Controllers
- `app/controllers/procedure_templates_controller.rb` - Admin CRUD
- `app/controllers/lab_flow_settings_controller.rb` - Project settings
- `app/controllers/wiki_templates_controller.rb` - JSON API

### Views
- `app/views/procedure_templates/index.html.erb`
- `app/views/procedure_templates/new.html.erb`
- `app/views/procedure_templates/edit.html.erb`
- `app/views/procedure_templates/_form.html.erb`
- `app/views/projects/settings/_lab_flow.html.erb`
- `app/views/hooks/redmine_lab_flow/_wiki_edit_template_selector.html.erb`
- `app/views/hooks/redmine_lab_flow/_issue_edit_notes.html.erb`
- `app/views/hooks/redmine_lab_flow/_issue_show_details.html.erb`
- `app/views/hooks/redmine_lab_flow/_html_head.html.erb`

### Core Logic
- `lib/redmine_lab_flow/issue_patch.rb` - Finalization logic

### Helpers
- `app/helpers/lab_flow_helper.rb` - Finalization helper methods

---

## Modified Files

### `init.rb`
- Version bump to 0.2.0
- Admin menu for Procedure Templates
- Project settings tab
- Extended permissions

### `lib/redmine_lab_flow/setup.rb`
- Added `field_procedure_reference` to Daily Log
- Added `create_finalized_status` method

### `lib/redmine_lab_flow/hooks.rb`
- Issue edit notes hook
- Issue show details hook
- HTML head hook
- Wiki edit template selector

### `config/routes.rb`
- Procedure templates routes
- Wiki templates routes
- Lab flow settings route

### `config/locales/en.yml`
- ~25 new translation keys

---

## i18n Keys Added

```yaml
# Procedure Templates
label_procedure_templates: "Procedure Templates"
label_procedure_template: "Procedure Template"
label_procedure_template_new: "New Procedure Template"
label_procedure_template_edit: "Edit Procedure Template"
label_select_procedure_template: "Select Template"
label_no_template: "-- No Template --"

# Procedure Reference
field_procedure_reference: "Procedure Reference"
label_wiki_reference: "Wiki Reference"

# Finalization
label_status_finalized: "Finalized"
label_finalized: "Finalized"
field_finalization_status: "Finalization Status"
setting_allow_admin_unlock_finalized: "Allow administrators to edit finalized records"

# Audit
error_reason_for_change_required: "Reason for change is required when editing Daily Log entries"
text_reason_for_change_required: "A reason for change is required in the Notes field for audit compliance."
```

---

## Architecture Decisions

1. **Dedicated Template Table**: Templates stored in plugin-specific table for admin UI
2. **Version-Locked References**: Wiki links store specific version for reproducibility
3. **Journal-Based Audit**: Uses existing Redmine journal system for change tracking
4. **Project-Level Configuration**: Finalization behavior configurable per project
5. **Module Prepending**: Issue patch uses Rails module prepending pattern

---

## Usage

### Create Procedure Template
1. Go to Administration > Procedure Templates
2. Click "New Procedure Template"
3. Enter name, description, and Markdown content
4. Save

### Use Template in Wiki
1. Go to project Wiki
2. Create new page
3. Select template from dropdown
4. Template content is pre-filled

### Link Daily Log to Procedure
1. Edit Daily Log issue
2. Select procedure from "Procedure Reference" dropdown
3. Version is automatically locked

### Finalize Record
1. Change Daily Log status to "Finalized"
2. Record becomes read-only
3. Only admins can edit (if project allows)

### Configure Admin Unlock
1. Go to Project Settings > Lab Flow
2. Toggle "Allow administrators to edit finalized records"
3. Save

---

## Example Data

### Rake Tasks

```bash
# Seed procedure templates only
bundle exec rake lab_flow:seed_templates

# Seed Wiki SOPs for a specific project
bundle exec rake lab_flow:seed_wiki_sops PROJECT=my-project

# Create complete demo project with all features
bundle exec rake lab_flow:create_example_project
```

### Included Procedure Templates (6)

1. **Standard Operating Procedure (SOP)** - General template with all sections
2. **Sample Preparation Protocol** - Detailed sample prep workflow
3. **Analytical Method Protocol** - HPLC/GC method template
4. **Equipment Calibration Log** - Calibration record template
5. **Daily Lab Notebook Entry** - Daily ELN entry template
6. **Investigation Report** - Root cause analysis template

### Demo Project Contents

The `lab_flow:create_example_project` task creates:

- **Project**: LabFlow Demo Project (`labflow-demo`)
- **Wiki Pages**: 3 example SOPs
  - Sample-Handling-SOP
  - HPLC-Analysis-Method
  - Quality-Control-Protocol
- **Sample Issues**: 3 examples (soil, water, reference standard)
- **Daily Log Issues**: 3 examples (setup, prep, analysis)
- **Assay Issues**: 3 examples (pH, Lead, TOC analyses)

---

## Version

- **Plugin Version**: 0.2.0
- **Requires Redmine**: 6.0.0+
