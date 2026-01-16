# Phase 1: ISA Laboratory Foundation

## Objective

Create an ISA-compliant laboratory management foundation for Redmine, enabling structured tracking of samples, daily logs, and assays using Redmine's native issue system.

---

## ISA Hierarchy Mapping

| ISA Concept | Redmine Entity |
|-------------|----------------|
| Investigation | Root Project |
| Stage | Subproject |
| Assay | Tracker + Issue |

---

## Components Implemented

### Trackers (3)

| Tracker | Description |
|---------|-------------|
| Sample | Physical sample tracking with unique identifiers |
| Daily Log | Electronic Lab Notebook entries |
| Assay | Quantitative measurements and analysis |

### Custom Fields (24)

#### Sample Tracker (6 fields)
- **Internal ID** (string, required) - Unique sample identifier
- **Sample Type** (list) - Biological, Chemical, Environmental, Control, Standard
- **Storage Location** (string) - Where sample is stored
- **Collection Date** (date) - When sample was collected
- **Expiration Date** (date) - Sample expiry date
- **Sample Source** (string) - Origin of sample

#### Daily Log Tracker (9 fields)
- **Experiment Reference** (string, required) - Reference identifier
- **Lab Conditions** (text) - Environmental conditions
- **Equipment Used** (text) - List of equipment
- **Observations** (text) - Notes and observations
- **Protocol Version** (string) - Version of protocol followed
- **Reviewed By** (user) - Reviewer assignment
- **Weather Conditions** (string) - External conditions
- **Start Time** (string) - Experiment start
- **End Time** (string) - Experiment end

#### Assay Tracker (6 fields)
- **Measured Value** (float, required) - Quantitative result
- **Unit** (list, configurable) - Measurement unit
- **Method** (string) - Analysis method used
- **Instrument** (string) - Equipment used
- **Detection Limit** (float) - Sensitivity threshold
- **Uncertainty** (string) - Measurement uncertainty

### Dashboard

Lab Flow index page showing:
- Issue counts per tracker
- Recent 5 issues per tracker
- Quick links to create new issues
- Filtered views by tracker

### Permissions

| Permission | Description |
|------------|-------------|
| view_lab_entities | View lab dashboard and entities (read-only on closed projects) |
| manage_lab_entities | Configure lab settings |

### Plugin Settings

- **Configurable Units**: Administrators can define available measurement units

---

## Files Created

### Core Files
- `init.rb` - Plugin registration, permissions, menus
- `lib/redmine_lab_flow/setup.rb` - Programmatic tracker/field creation
- `lib/redmine_lab_flow/hooks.rb` - View hooks for sidebar

### Controllers
- `app/controllers/lab_flow_controller.rb` - Dashboard controller

### Views
- `app/views/lab_flow/index.html.erb` - Main dashboard
- `app/views/hooks/redmine_lab_flow/_project_sidebar.html.erb` - Sidebar link
- `app/views/settings/_lab_flow_settings.html.erb` - Plugin settings

### Configuration
- `config/routes.rb` - Dashboard route
- `config/locales/en.yml` - 52 i18n translations

### Tests
- `test/test_helper.rb` - Test base class
- `test/unit/setup_test.rb` - 14 setup tests
- `test/functional/lab_flow_controller_test.rb` - 8 controller tests
- `test/integration/lab_flow_test.rb` - 4 integration tests

---

## Architecture Decisions

1. **No Database Migrations**: All data stored in standard Redmine tables (trackers, custom_fields, issues)
2. **Programmatic Setup**: Trackers and fields created via `Setup.install` on plugin load
3. **Idempotent Installation**: Safe to run multiple times without duplicating data
4. **Global Fields**: Custom fields apply to all projects (`is_for_all: true`)
5. **Module-Based Access**: Features toggle per project via `laboratory_management` module

---

## Usage

### Enable for Project
1. Go to Project Settings > Modules
2. Enable "Laboratory Management"
3. Lab Flow menu item appears in project menu

### Create Lab Entries
1. Click "New Sample", "New Daily Log", or "New Assay"
2. Fill in required custom fields
3. Submit issue

### Configure Units
1. Go to Administration > Plugins > LabFlow > Configure
2. Edit available units (one per line)
3. Save

---

## Version

- **Plugin Version**: 0.1.0
- **Requires Redmine**: 6.0.0+
