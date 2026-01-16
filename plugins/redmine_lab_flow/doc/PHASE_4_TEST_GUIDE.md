# Phase 4 - UI Testing Guide

This guide walks you through testing all Phase 4 features in the Redmine UI.

---

## Prerequisites

1. Redmine is running: `mise exec -- bundle exec rails server`
2. Plugin migrations have run: `mise exec -- bundle exec rake redmine:plugins:migrate`
3. You have admin access to Redmine
4. A project with "Laboratory Management" module enabled

---

## Test 1: Verified Status in Workflow

### Steps:

1. Go to **Administration > Issue statuses**
2. Verify that **"Verified"** status exists between QC Pending and Completed
3. Go to **Administration > Workflow > Status transitions**
4. Select the **Assay** tracker and any role
5. Verify the following transitions exist:
   - QC Pending → Verified
   - Verified → Completed
   - Verified → QC Pending (for corrections)

### Expected Result:
- "Verified" status should be visible in the workflow configuration
- Transitions should allow the complete lifecycle: Accessioned → In Analysis → QC Pending → Verified → Completed

---

## Test 2: Electronic Signature Modal

### Steps:

1. Create a new Assay in your project:
   - Go to **Lab Flow** > **New Assay**
   - Fill in required fields (Internal ID, Measured Value, etc.)
   - Save with status **Accessioned**

2. Progress through the workflow:
   - Edit the Assay, change status to **In Analysis**, provide a reason in Notes
   - Edit again, change status to **QC Pending**, provide a reason

3. Trigger the signature requirement:
   - Edit the Assay
   - Change status to **Verified**
   - Click **Submit**

### Expected Result:
- A modal dialog should appear requesting:
  - Your password
  - Signature meaning (Authorship/Review/Approval)
- If you enter the wrong password, an error should appear
- If you enter the correct password and select a meaning, the status change should proceed
- The signature should be recorded in the system

### Testing Invalid Password:

1. In the signature modal, enter an incorrect password
2. Click Submit

### Expected Result:
- Error message: "Invalid password. Electronic signature could not be verified."

---

## Test 3: Source Type Field

### Steps:

1. Create a new Assay via the web UI
2. View the Assay details

### Expected Result:
- The **Source Type** field should show "web"
- The field should not be editable by users

---

## Test 4: API Keys Management

### Steps:

1. Go to **Administration > Plugins > Redmine LabFlow > Configure**
2. Click on the **API Keys** tab

### Expected Result:
- You should see the API Keys management interface
- Options to create new API keys
- API usage examples with curl commands

### Creating an API Key:

1. In the API Keys tab, select a project from the dropdown
2. Add a description (e.g., "pH Meter Integration")
3. Click **Create**

### Expected Result:
- A new API key should be created
- The key should appear in the list with:
  - Project name
  - Description
  - Masked key (first 8 and last 4 characters visible)
  - Active status
  - Creation date

### Copy API Key:

1. Click the copy button next to the masked key

### Expected Result:
- The full API key should be copied to your clipboard
- An alert should confirm "API key copied to clipboard"

---

## Test 5: REST API - Get Assay

### Prerequisites:
- An API key created for your project
- An Assay with a known Internal ID

### Steps (using curl):

```bash
# Replace YOUR_API_KEY with your actual API key
# Replace INTERNAL_ID with your assay's Internal ID
# Replace localhost:3000 with your Redmine URL

curl -H "X-API-Key: YOUR_API_KEY" \
  http://localhost:3000/lab_flow_api/assays/INTERNAL_ID
```

### Expected Result:
```json
{
  "id": 123,
  "internal_id": "TEST-001",
  "subject": "pH Analysis",
  "status": "In Analysis",
  "project": "my-project",
  "custom_fields": [...]
}
```

---

## Test 6: REST API - Update Assay

### Steps (using curl):

```bash
curl -X POST \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_fields": {
      "Measured Value": "7.35"
    },
    "notes": "Updated from test script"
  }' \
  http://localhost:3000/lab_flow_api/assays/INTERNAL_ID
```

### Expected Result:
- Response should indicate success
- The Assay should be updated with the new Measured Value
- A journal entry should record the change with the note
- The Source Type should change to "api"

### Verify in UI:

1. Open the Assay in Redmine
2. Check the **Source Type** field

### Expected Result:
- Source Type should now show "api" instead of "web"

---

## Test 7: API Authentication Failure

### Steps:

```bash
# Try with invalid API key
curl -H "X-API-Key: invalid_key_12345" \
  http://localhost:3000/lab_flow_api/assays/INTERNAL_ID
```

### Expected Result:
- HTTP 401 Unauthorized response
- Error message indicating authentication failed

---

## Test 8: User API Token Authentication

### Steps:

1. Get your user API token from **My Account > API access key**
2. Make an API request:

```bash
curl -H "X-Redmine-API-Key: YOUR_USER_TOKEN" \
  http://localhost:3000/lab_flow_api/assays/INTERNAL_ID
```

### Expected Result:
- Request should succeed
- You should receive the Assay details

---

## Test 9: Project Access Control

### Steps:

1. Create an API key for Project A
2. Create an Assay in Project B
3. Try to access the Project B Assay using Project A's API key:

```bash
curl -H "X-API-Key: PROJECT_A_API_KEY" \
  http://localhost:3000/lab_flow_api/assays/PROJECT_B_INTERNAL_ID
```

### Expected Result:
- HTTP 403 Forbidden response
- Error message: "Access denied to this project"

---

## Test 10: Regenerate API Key

### Steps:

1. Go to **Administration > Plugins > Redmine LabFlow > Configure > API Keys**
2. Find an existing API key
3. Click **Regenerate**
4. Confirm the action

### Expected Result:
- The API key should be regenerated
- A new key should be displayed (different from the old one)
- The old key should no longer work

### Verify Old Key Stopped Working:

```bash
# Use the old API key
curl -H "X-API-Key: OLD_API_KEY" \
  http://localhost:3000/lab_flow_api/assays/INTERNAL_ID
```

### Expected Result:
- HTTP 401 Unauthorized response

---

## Test 11: Deactivate API Key

### Steps:

1. Edit an API key in the settings
2. Uncheck the **Active** checkbox
3. Save

### Expected Result:
- The API key should be marked as inactive
- The key should no longer work for API requests

---

## Test 12: Complete Workflow with Signatures

This is an end-to-end test of the full Assay workflow with electronic signatures.

### Steps:

1. **Create Assay**: New Assay with Internal ID "E2E-TEST-001"
2. **Accessioned → In Analysis**: Change status, provide reason
3. **In Analysis → QC Pending**: Change status, provide reason
4. **QC Pending → Verified**:
   - Change status
   - Modal appears
   - Enter password and select "Review"
   - Submit
5. **Verified → Completed**:
   - Change status
   - Modal appears
   - Enter password and select "Approval"
   - Submit

### Expected Result:
- Each step should complete successfully
- Two electronic signatures should be recorded
- The Assay should end in "Completed" status

---

## Troubleshooting

### Modal doesn't appear

1. Check browser console for JavaScript errors
2. Verify the Assay is using the Assay tracker (not a different tracker)
3. Check that the "Verified" and "Completed" statuses exist

### API returns 404

1. Verify the Internal ID field exists and is configured for the Assay tracker
2. Check that the Assay has a value in the Internal ID field
3. Verify the API key is for the correct project

### Signature verification fails

1. Ensure you're using your correct Redmine password
2. Check that your user account is active
3. Verify the user has permission to edit issues in the project

---

## Test Summary Checklist

- [ ] Verified status exists in workflow
- [ ] Workflow transitions include Verified
- [ ] Electronic signature modal appears for Verified status
- [ ] Electronic signature modal appears for Completed status
- [ ] Invalid password shows error
- [ ] Correct password allows status change
- [ ] Source Type field shows "web" for UI entries
- [ ] API Keys tab appears in plugin settings
- [ ] Can create new API key
- [ ] Can copy API key to clipboard
- [ ] API GET request works with valid key
- [ ] API POST request updates Assay
- [ ] API updates set Source Type to "api"
- [ ] Invalid API key returns 401
- [ ] User API token authentication works
- [ ] Cross-project access is denied
- [ ] Can regenerate API key
- [ ] Can deactivate API key
- [ ] Complete workflow with signatures succeeds
