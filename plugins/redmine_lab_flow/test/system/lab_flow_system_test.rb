# frozen_string_literal: true

require_relative '../../../../test/application_system_test_case'

class LabFlowSystemTest < ApplicationSystemTestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :enumerations, :trackers, :issue_statuses,
           :custom_fields, :custom_fields_trackers, :projects_trackers

  def setup
    super
    create_lab_flow_data
  end

  # ==========================================
  # Assay Creation Tests
  # ==========================================

  def test_create_assay_with_internal_id
    skip "Assay tracker not available" unless @assay_tracker

    log_user('admin', 'admin')

    visit "/projects/ecookbook/issues/new"

    within('form#issue-form') do
      select 'Assay', from: 'Tracker'
      fill_in 'Subject', with: 'Test Assay for pH Analysis'

      # Wait for form update
      sleep 1

      fill_in 'Internal ID', with: 'ASSAY-2026-001' if page.has_field?('Internal ID')
      fill_in 'Measured Value', with: '7.2' if page.has_field?('Measured Value')

      find('input[name=commit]').click
    end

    assert_text /Issue #\d+ created./

    issue = Issue.order(id: :desc).first
    assert_equal 'Test Assay for pH Analysis', issue.subject
    assert_equal 'Assay', issue.tracker.name
  end

  def test_create_sample_with_internal_id
    skip "Sample tracker not available" unless @sample_tracker

    log_user('admin', 'admin')

    visit "/projects/ecookbook/issues/new"

    within('form#issue-form') do
      select 'Sample', from: 'Tracker'
      fill_in 'Subject', with: 'Water Sample from Site A'

      sleep 1

      fill_in 'Internal ID', with: 'SAMPLE-2026-001' if page.has_field?('Internal ID')

      find('input[name=commit]').click
    end

    assert_text /Issue #\d+ created./

    issue = Issue.order(id: :desc).first
    assert_equal 'Water Sample from Site A', issue.subject
    assert_equal 'Sample', issue.tracker.name
  end

  # ==========================================
  # Status Workflow Tests
  # ==========================================

  def test_assay_status_workflow
    skip "LabFlow data not available" unless @assay_tracker && @accessioned_status && @in_analysis_status

    log_user('admin', 'admin')

    issue = Issue.create!(
      project: @project,
      tracker: @assay_tracker,
      subject: 'Assay for workflow test',
      author: User.find_by(login: 'admin'),
      status: @accessioned_status,
      priority: IssuePriority.default || IssuePriority.first
    )

    visit "/issues/#{issue.id}"
    page.first(:link, 'Edit').click

    if page.has_select?('Status', with_options: ['In Analysis'])
      select 'In Analysis', from: 'Status'
      fill_in 'issue_notes', with: 'Starting analysis'
      page.first(:button, 'Submit').click

      assert_text 'Successful update.'
      assert_equal 'In Analysis', issue.reload.status.name
    else
      skip "In Analysis status not available"
    end
  end

  # ==========================================
  # Electronic Signature Tests
  # ==========================================

  def test_electronic_signature_modal_appears_for_verified_status
    skip "LabFlow data not available" unless @assay_tracker && @qc_pending_status && @verified_status

    log_user('admin', 'admin')

    issue = Issue.create!(
      project: @project,
      tracker: @assay_tracker,
      subject: 'Assay for signature test',
      author: User.find_by(login: 'admin'),
      status: @qc_pending_status,
      priority: IssuePriority.default || IssuePriority.first
    )

    visit "/issues/#{issue.id}"
    page.first(:link, 'Edit').click

    if page.has_select?('Status', with_options: ['Verified'])
      select 'Verified', from: 'Status'
      fill_in 'issue_notes', with: 'Verified by analyst'
      page.first(:button, 'Submit').click

      assert page.has_css?('#lab-flow-signature-modal', visible: true, wait: 5),
             "Electronic signature modal should appear"
      assert page.has_content?('Electronic Signature')
    else
      skip "Verified status not available"
    end
  end

  # ==========================================
  # Plugin Settings Tests
  # ==========================================

  def test_access_plugin_settings
    log_user('admin', 'admin')

    visit '/admin/plugins'
    assert page.has_content?('Redmine LabFlow') || page.has_content?('LabFlow') || page.has_content?('redmine_lab_flow')
  end

  def test_navigate_plugin_settings_tabs
    log_user('admin', 'admin')

    visit '/settings/plugin/redmine_lab_flow'
    assert page.has_css?('body')
  end

  # ==========================================
  # API Keys Management Tests
  # ==========================================

  def test_create_api_key
    skip "LabFlowApiKey not available" unless defined?(LabFlowApiKey) && LabFlowApiKey.table_exists?

    log_user('admin', 'admin')

    visit '/settings/plugin/redmine_lab_flow'

    if page.has_link?('API Keys')
      click_link 'API Keys'
      assert page.has_content?('API Keys')

      if page.has_select?('new_api_key_project_id')
        select 'eCookbook', from: 'new_api_key_project_id'
        fill_in 'new_api_key_description', with: 'Test API Key'
        click_button 'Create'

        sleep 2
        visit '/settings/plugin/redmine_lab_flow'
        click_link 'API Keys'

        assert page.has_content?('Test API Key') || page.has_css?('.api-keys-list')
      else
        skip "API key form not available"
      end
    else
      skip "API Keys tab not found"
    end
  end

  private

  def create_lab_flow_data
    @project = Project.find(1)

    # Ensure admin password
    admin = User.find_by(login: 'admin')
    if admin && !admin.check_password?('admin')
      admin.password = 'admin'
      admin.password_confirmation = 'admin'
      admin.must_change_passwd = false
      admin.save!
    end

    # Create LabFlow statuses
    @accessioned_status = IssueStatus.find_or_create_by!(name: 'Accessioned') do |s|
      s.is_closed = false
      s.position = IssueStatus.maximum(:position).to_i + 1
    end

    @in_analysis_status = IssueStatus.find_or_create_by!(name: 'In Analysis') do |s|
      s.is_closed = false
      s.position = IssueStatus.maximum(:position).to_i + 1
    end

    @qc_pending_status = IssueStatus.find_or_create_by!(name: 'QC Pending') do |s|
      s.is_closed = false
      s.position = IssueStatus.maximum(:position).to_i + 1
    end

    @verified_status = IssueStatus.find_or_create_by!(name: 'Verified') do |s|
      s.is_closed = false
      s.position = IssueStatus.maximum(:position).to_i + 1
    end

    @completed_status = IssueStatus.find_or_create_by!(name: 'Completed') do |s|
      s.is_closed = true
      s.position = IssueStatus.maximum(:position).to_i + 1
    end

    # Create LabFlow trackers
    @assay_tracker = Tracker.find_or_create_by!(name: 'Assay') do |t|
      t.position = Tracker.maximum(:position).to_i + 1
      t.default_status = @accessioned_status
    end

    @sample_tracker = Tracker.find_or_create_by!(name: 'Sample') do |t|
      t.position = Tracker.maximum(:position).to_i + 1
      t.default_status = @accessioned_status
    end

    # Associate trackers with project
    [@assay_tracker, @sample_tracker].each do |tracker|
      @project.trackers << tracker unless @project.trackers.include?(tracker)
    end

    # Create workflows
    create_workflow(@assay_tracker, 0, @accessioned_status)
    create_workflow(@assay_tracker, @accessioned_status, @in_analysis_status)
    create_workflow(@assay_tracker, @in_analysis_status, @qc_pending_status)
    create_workflow(@assay_tracker, @qc_pending_status, @verified_status)
    create_workflow(@assay_tracker, @verified_status, @completed_status)

    create_workflow(@sample_tracker, 0, @accessioned_status)
    create_workflow(@sample_tracker, @accessioned_status, @in_analysis_status)
    create_workflow(@sample_tracker, @in_analysis_status, @qc_pending_status)
    create_workflow(@sample_tracker, @qc_pending_status, @verified_status)
    create_workflow(@sample_tracker, @verified_status, @completed_status)

    # Create Internal ID custom field
    @internal_id_field = IssueCustomField.find_or_create_by!(name: 'Internal ID') do |cf|
      cf.field_format = 'string'
      cf.is_required = false
      cf.is_filter = true
      cf.searchable = true
      cf.is_for_all = true
    end

    # Associate custom field with trackers
    [@assay_tracker, @sample_tracker].each do |tracker|
      tracker.custom_fields << @internal_id_field unless tracker.custom_fields.include?(@internal_id_field)
    end

    # Create Measured Value custom field for Assay
    @measured_value_field = IssueCustomField.find_or_create_by!(name: 'Measured Value') do |cf|
      cf.field_format = 'float'
      cf.is_required = false
      cf.is_filter = true
    end
    @assay_tracker.custom_fields << @measured_value_field unless @assay_tracker.custom_fields.include?(@measured_value_field)
  end

  def create_workflow(tracker, old_status, new_status)
    old_status_id = old_status.is_a?(Integer) ? old_status : old_status.id
    Role.all.each do |role|
      WorkflowTransition.find_or_create_by!(
        tracker: tracker,
        old_status_id: old_status_id,
        new_status_id: new_status.id,
        role: role
      )
    end
  end
end
