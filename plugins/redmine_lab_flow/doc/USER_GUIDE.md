# LabFlow Plugin - User Guide

## Introduction

LabFlow is a Redmine plugin that transforms Redmine into an Electronic Lab Notebook (ELN) and Laboratory Information Management System (LIMS). It follows the ISA (Investigation-Study-Assay) framework for organizing laboratory data.

---

## Getting Started

### 1. Enable the Module

1. Go to your project's **Settings**
2. Click on the **Modules** tab
3. Check **Laboratory Management**
4. Click **Save**

A new **Lab Flow** menu item will appear in your project menu.

---

## Core Concepts

### ISA Hierarchy Mapping

| ISA Concept | Redmine Entity |
|-------------|----------------|
| Investigation | Root Project |
| Study | Subproject |
| Assay | Tracker + Issue |

### Trackers

LabFlow creates three specialized trackers:

| Tracker | Purpose | Default Status |
|---------|---------|----------------|
| **Sample** | Track physical samples with unique identifiers | Accessioned |
| **Daily Log** | Electronic Lab Notebook entries | In Progress |
| **Assay** | Quantitative measurements and analysis results | Accessioned |

### Workflow Statuses

LabFlow automatically creates and configures the following statuses:

**For Sample and Assay trackers (LIMS workflow):**

| Status | Type | Description |
|--------|------|-------------|
| **Accessioned** | Open | Initial registration of the item |
| **In Analysis** | Open | Technical execution phase |
| **QC Pending** | Open | Awaiting quality control validation |
| **Completed** | Closed | Final, immutable state |

**Workflow transitions:** Accessioned → In Analysis → QC Pending → Completed

**For Daily Log tracker (ELN workflow):**

| Status | Type | Description |
|--------|------|-------------|
| **In Progress** | Open | Active lab notebook entry |
| **Finalized** | Closed | Immutable record for IP protection |

**Workflow transitions:** In Progress → Finalized

---

## Working with Samples

### Creating a Sample

1. Go to **Lab Flow** in the project menu
2. Click **New Sample**
3. The sample will be created with status **Accessioned**
4. Fill in the required fields:
   - **Subject**: Descriptive name (e.g., "Soil Sample A-001")
   - **Internal ID** (required): Unique identifier (e.g., "SOIL-2024-001")
   - **Sample Type**: Select from Biological, Chemical, Environmental, Control, Standard
   - **Storage Location**: Where the sample is stored
   - **Collection Date**: When the sample was collected
   - **Expiration Date**: Sample expiry date
   - **Sample Source**: Origin of the sample
   - **Equipment ID**: Select the equipment used (optional)

### Sample Workflow

Samples follow this lifecycle:

1. **Accessioned** - Sample is registered in the system
2. **In Analysis** - Sample is being processed or analyzed
3. **QC Pending** - Awaiting quality control review
4. **Completed** - Sample processing is complete (immutable)

### Sample Best Practices

- Use consistent naming conventions for Internal IDs
- Always record storage location for traceability
- Set expiration dates for time-sensitive samples
- Link related samples using Redmine's issue relations

---

## Working with Daily Logs

### Creating a Daily Log Entry

1. Go to **Lab Flow** in the project menu
2. Click **New Daily Log**
3. The entry will be created with status **In Progress**
4. Fill in the fields:
   - **Subject**: Brief description of the day's work
   - **Experiment Reference** (required): Reference identifier (e.g., "EXP-2024-001")
   - **Description**: Detailed notes using Markdown formatting
   - **Lab Conditions**: Environmental conditions during work
   - **Equipment Used**: List of equipment utilized
   - **Observations**: Notes and observations
   - **Protocol Version**: Version of protocol followed
   - **Start Time / End Time**: Work duration
   - **Procedure Reference**: Link to a Wiki SOP (versioned)

### Daily Log Workflow

Daily Logs follow a simple two-state workflow:

1. **In Progress** - Entry is being written or updated
2. **Finalized** - Entry is locked for IP protection (immutable)

Once finalized, the Daily Log cannot be edited (unless admin override is enabled).

### Daily Log Best Practices

- Write entries the same day work is performed
- Use Markdown formatting for structured notes
- Link to procedure Wiki pages for reproducibility
- Include all relevant observations, even unexpected ones
- Finalize entries when complete to protect intellectual property

### Wiki Integration

LabFlow provides seamless Wiki integration directly from issues.

#### Viewing Linked Wiki Pages

When viewing an issue, if there's a linked Wiki page, it will be displayed in the issue details:
- Click the Wiki page title to open it
- The version number is shown (e.g., "v3") for traceability

#### Creating a Wiki Page from an Issue

1. Open any issue in a project with Laboratory Management enabled
2. In the issue details, find **Linked Wiki Page**
3. If no Wiki is linked, click **Create Wiki Page**
4. A form appears with:
   - Pre-filled title based on the issue
   - Template content with issue details
   - Optional template selector to use a procedure template
5. Edit the content as needed
6. Click **Create**

The new Wiki page is automatically linked to the issue via the Procedure Reference field.

#### Linking to Existing Procedures

The **Procedure Reference** field allows you to link a Daily Log to a specific version of a Wiki page:

1. Edit your Daily Log
2. In **Procedure Reference**, select a Wiki page from the dropdown
3. The system automatically locks to the current version
4. The link displays as "Page Title (v3)" format

This ensures reproducibility - even if the Wiki page is updated later, your Daily Log references the exact version you followed.

---

## Working with Assays

### Creating an Assay

1. Go to **Lab Flow** in the project menu
2. Click **New Assay**
3. The assay will be created with status **Accessioned**
4. Fill in the fields:
   - **Subject**: What was analyzed (e.g., "pH Analysis - SOIL-2024-001")
   - **Measured Value** (required): Quantitative result
   - **Unit** (required): Measurement unit (mg, mL, %, units, etc.)
   - **Method**: Analysis method used (e.g., "EPA 9045D")
   - **Instrument**: Equipment used for analysis
   - **Detection Limit**: Sensitivity threshold
   - **Uncertainty**: Measurement uncertainty
   - **Lot Number**: Select the reagent lot used (for traceability)
   - **Equipment ID**: Select the equipment used

### Assay Workflow

Assays follow a controlled LIMS workflow with electronic signature requirements:

```
Accessioned → In Analysis → QC Pending → Verified → Completed
     ↑              ↓              ↓           ↓
     └──────────────┴──────────────┴───────────┘
         (corrections allowed)
```

| Status | Description | Signature Required | Actions |
|--------|-------------|-------------------|---------|
| **Accessioned** | Initial registration | No | Move to In Analysis |
| **In Analysis** | Technical execution | No | Move to QC Pending or back to Accessioned |
| **QC Pending** | Quality control validation | No | Move to Verified or back to In Analysis |
| **Verified** | Data verified by reviewer | **Yes** | Move to Completed or back to QC Pending |
| **Completed** | Final, immutable state | **Yes** | No further changes |

**Note:** Transitions to "Verified" and "Completed" require an electronic signature (re-authentication).

### Assay Validation Rules

**Expired Reagent Check:** An Assay **cannot** be moved to "Completed" if the selected **Lot Number** is linked to a reagent with an expiration date in the past. This ensures:

- Only valid materials are used for final results
- Compliance with quality standards
- Full traceability of materials

**Reason for Change:** When editing an Assay, you must provide a reason in the Notes field (audit compliance).

### Assay Best Practices

- Link assays to their source samples using issue relations
- Always record the method and instrument used
- Document detection limits for quality assurance
- Include uncertainty for regulatory compliance
- **Always select the reagent lot number** used for traceability
- **Always select the equipment** used for the analysis
- Move through workflow states as work progresses
- Only move to "Completed" after QC review

---

## Lab Flow Dashboard

The Lab Flow dashboard provides an overview of all laboratory activities:

- **Issue counts** per tracker (Samples, Daily Logs, Assays)
- **Recent entries** showing the last 5 issues per tracker
- **Quick links** to create new entries
- **Filtered views** by tracker type

Access it via **Lab Flow** in the project menu.

---

## Plugin Administration

All administrative functions for LabFlow are centralized in the plugin settings page.

### Accessing Plugin Settings

1. Go to **Administration > Plugins**
2. Find **Redmine LabFlow** and click **Configure**
3. You will see four tabs:
   - **Procedure Templates** - Manage SOP templates
   - **Lab Reagents** - Manage reagent inventory
   - **Lab Equipment** - Manage equipment inventory
   - **Available Units** - Configure measurement units

---

## Procedure Templates (Admin)

Administrators can create reusable SOP templates.

### Creating a Template

1. Go to **Administration > Plugins > Redmine LabFlow > Configure**
2. Select the **Procedure Templates** tab
3. Click **New Procedure Template**
4. Fill in:
   - **Name**: Template name (e.g., "Standard Operating Procedure")
   - **Description**: Brief description
   - **Content**: Markdown template content
   - **Active**: Whether template is available for use
5. Click **Create**

### Using Templates in Wiki

1. Go to your project's **Wiki**
2. Click to create a new page
3. Select a template from the **Procedure Template** dropdown
4. The template content is pre-filled in the editor
5. Customize as needed and save

### Included Templates

LabFlow includes 6 pre-built templates:

1. **Standard Operating Procedure (SOP)** - General template with all sections
2. **Sample Preparation Protocol** - Detailed sample prep workflow
3. **Analytical Method Protocol** - HPLC/GC method template
4. **Equipment Calibration Log** - Calibration record template
5. **Daily Lab Notebook Entry** - Daily ELN entry template
6. **Investigation Report** - Root cause analysis template

---

## Record Finalization (IP Protection)

For intellectual property protection and regulatory compliance, Daily Log records can be finalized to become immutable.

### Finalizing a Daily Log

1. Edit a Daily Log issue (must be in **In Progress** status)
2. Change the status to **Finalized**
3. Provide a reason for change in the Notes field
4. Save the issue

Once finalized:
- Description becomes read-only
- Custom fields cannot be modified
- A "Finalized" badge appears on the issue
- The record serves as legal evidence of work performed

### Admin Override

Project administrators can configure whether admins can edit finalized records:

1. Go to **Project Settings > Lab Flow**
2. Toggle **Allow administrators to edit finalized records**
3. Save

**Note:** Even with admin override, all changes are tracked in the issue journal for audit compliance.

---

## Audit Compliance (21 CFR Part 11)

### Reason for Change

When editing Daily Log or Assay entries, you must provide a reason for change in the Notes field. This ensures audit compliance:

1. Edit a Daily Log or Assay
2. Make your changes
3. In the **Notes** field, explain why you made the change
4. Submit

The reason is recorded in the issue's journal/history for audit purposes.

---

## Inventory Management (Admin)

LabFlow includes a complete inventory management system for reagents and equipment, accessible from the plugin settings page.

### Managing Reagents

Access via **Administration > Plugins > Redmine LabFlow > Configure > Lab Reagents**

#### Creating a Reagent

1. Click **New Reagent**
2. Fill in the fields:
   - **Name** (required): Reagent name (e.g., "Hydrochloric Acid")
   - **Lot Number** (required): Unique lot identifier (e.g., "LOT-2024-001")
   - **Expiration Date**: When the reagent expires
   - **Quantity**: Amount available
   - **Unit**: Measurement unit (mL, g, etc.)
   - **Supplier**: Vendor name
   - **Catalog Number**: Supplier's catalog number
   - **Storage Conditions**: How to store (e.g., "2-8C")
   - **Active**: Whether available for use
3. Click **Create**

#### Reagent Alerts

The system displays warnings for:
- **Expired reagents**: Red badge, requires immediate attention
- **Expiring soon**: Yellow badge, reagents expiring within 30 days

#### Using Reagents in Assays

When creating or editing an Assay, select the reagent lot from the **Lot Number** dropdown. This ensures:
- Full traceability of materials used
- Automatic validation against expired reagents
- Compliance with quality standards

**Important:** An Assay cannot be completed if it uses an expired reagent.

### Managing Equipment

Access via **Administration > Plugins > Redmine LabFlow > Configure > Lab Equipment**

#### Creating Equipment

1. Click **New Equipment**
2. Fill in the fields:
   - **Name** (required): Equipment name (e.g., "pH Meter")
   - **Serial Number**: Unique identifier
   - **Model**: Equipment model
   - **Manufacturer**: Equipment manufacturer
   - **Calibration Due**: Next calibration date
   - **Last Calibration**: Most recent calibration date
   - **Location**: Where the equipment is stored
   - **Status**: Current availability status
   - **Active**: Whether available for use
3. Click **Create**

#### Equipment Status

| Status | Description |
|--------|-------------|
| **Available** | Ready for use |
| **In Use** | Currently being used |
| **Maintenance** | Under maintenance |
| **Out of Service** | Not available |

#### Calibration Alerts

The system displays warnings for:
- **Calibration overdue**: Red badge, requires immediate attention
- **Calibration due soon**: Yellow badge, due within 30 days

#### Using Equipment in Issues

When creating Samples or Assays, select the equipment from the **Equipment ID** dropdown for full traceability.

---

## Plugin Settings (Admin)

### Configuring Units

1. Go to **Administration > Plugins > Redmine LabFlow > Configure**
2. Select the **Available Units** tab
3. Edit the **Configurable Units** list (one per line)
4. Click **Apply** to save

Default units: mg, mL, g, L, %, ppm, ppb, units, mol, mmol

---

## Permissions

| Permission | Description |
|------------|-------------|
| **View lab entities** | View lab dashboard and entities |
| **Manage lab entities** | Configure lab settings |

Assign these permissions to roles via **Administration > Roles and Permissions**.

---

## Rake Tasks

```bash
# Seed procedure templates only
bundle exec rake lab_flow:seed_templates

# Seed Wiki SOPs for a specific project
bundle exec rake lab_flow:seed_wiki_sops PROJECT=my-project

# Create complete demo project with all features
bundle exec rake lab_flow:create_example_project
```

---

## Tips and Workflows

### Recommended Workflow

1. **Plan**: Create Wiki pages for your SOPs using procedure templates
2. **Prepare**: Register samples with Internal IDs
3. **Execute**: Create Daily Log entries linked to procedures
4. **Analyze**: Record results as Assay issues linked to samples
5. **Finalize**: Mark completed records as Finalized

### Linking Issues

Use Redmine's built-in issue relations to connect:
- Daily Logs → Samples (relates to)
- Assays → Samples (relates to)
- Assays → Daily Logs (follows)

### Search and Filter

Use Redmine's issue filters to find:
- All samples by type
- Daily logs by experiment reference
- Assays by method or value range

---

## Troubleshooting

### Module not appearing
- Ensure the plugin is installed correctly
- Check that migrations have run: `rake redmine:plugins:migrate`
- Verify the module is enabled in project settings

### Custom fields not showing
- The plugin auto-creates fields on startup
- Restart Redmine if fields are missing
- Check that trackers are associated with the project

### Finalization not working
- Ensure the "Finalized" status exists
- Check user permissions
- Verify project settings for admin override

---

## Electronic Signatures (Compliance)

Phase 4 introduces electronic signatures for regulatory compliance (21 CFR Part 11).

### When Signatures are Required

Electronic signatures are required when changing an Assay or Sample status to:
- **Verified** - Data has been reviewed and verified
- **Completed** - Final approval of results

### How Electronic Signatures Work

1. When you attempt to change status to Verified or Completed:
2. A modal dialog appears requesting:
   - **Password**: Your current Redmine password (re-authentication)
   - **Signature Meaning**: Select one of:
     - **Authorship** - You are the author/creator of this data
     - **Review** - You have reviewed this data
     - **Approval** - You are approving this data
3. After successful verification, the status change proceeds
4. The signature is recorded with:
   - User identity
   - Timestamp
   - IP address
   - Previous and new status
   - Signature meaning

### Viewing Signature History

Signatures are recorded in the system for audit purposes. Each signature includes:
- Who signed
- When they signed
- What they attested to (authorship/review/approval)
- The status change that was made

---

## Data Provenance (Source Type)

Phase 4 tracks the origin of all data entries:

| Source Type | Description |
|-------------|-------------|
| **Web Interface** | Data entered manually through the Redmine UI |
| **API/Instrument** | Data submitted via the REST API by external instruments |

The **Source Type** field is automatically set and cannot be modified by users. This ensures complete traceability of data origin for audit compliance.

---

## API for Instrument Interoperability

LabFlow provides a REST API for external instruments and systems to submit data directly.

### API Authentication

Two authentication methods are supported:

1. **Project API Key** (recommended for instruments):
   - Header: `X-API-Key: <your_project_api_key>`
   - Limited to a specific project
   - Managed in plugin settings

2. **User API Token** (for user-specific access):
   - Header: `X-Redmine-API-Key: <your_user_api_token>`
   - Uses your personal Redmine API token
   - Inherits your user permissions

### Managing API Keys (Admin)

1. Go to **Administration > Plugins > Redmine LabFlow > Configure**
2. Select the **API Keys** tab
3. Click **New API Key**
4. Select a project and add a description
5. Click **Create**
6. Copy the generated API key (shown only once)

### API Endpoints

#### Get Assay by Internal ID

```bash
curl -H "X-API-Key: YOUR_API_KEY" \
  https://your-redmine.com/lab_flow_api/assays/INTERNAL_ID
```

Response:
```json
{
  "id": 123,
  "internal_id": "TEST-001",
  "subject": "pH Analysis",
  "status": "In Analysis",
  "project": "my-project",
  "custom_fields": [
    {"name": "Measured Value", "value": "7.2"},
    {"name": "Unit", "value": "pH"}
  ]
}
```

#### Update Assay from Instrument

```bash
curl -X POST \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_fields": {
      "Measured Value": "7.35",
      "Unit": "pH"
    },
    "notes": "Updated from pH meter instrument"
  }' \
  https://your-redmine.com/lab_flow_api/assays/INTERNAL_ID
```

Response:
```json
{
  "success": true,
  "issue_id": 123,
  "internal_id": "TEST-001",
  "message": "Assay was successfully updated via API."
}
```

#### List Project Assays

```bash
curl -H "X-API-Key: YOUR_API_KEY" \
  https://your-redmine.com/lab_flow_api/projects/PROJECT_ID/assays
```

### API Security Notes

- API keys are project-specific and can only access assays in that project
- All API updates are logged with source_type = "api"
- API updates require notes/reason for audit trail
- Inactive API keys are rejected immediately

---

## Version History

- **0.4.0** - Phase 4: Compliance & Data Integrity (Electronic Signatures, API Interoperability, Data Provenance, Verified Status)
- **0.3.2** - Fixed workflow configuration: proper default statuses and transitions for all trackers
- **0.3.1** - Unified plugin administration with tabbed interface for Templates, Reagents, Equipment, and Units
- **0.3.0** - Phase 3: LIMS Core & Inventory Management (Reagents, Equipment, Workflow States, Expired Reagent Validation)
- **0.2.0** - Phase 2: ELN Integration (Procedure Templates, Wiki Reference, Finalization)
- **0.1.0** - Phase 1: ISA Laboratory Foundation (Trackers, Custom Fields, Dashboard)
