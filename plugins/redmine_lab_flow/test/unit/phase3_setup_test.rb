# frozen_string_literal: true

require_relative '../test_helper'

class Phase3SetupTest < RedmineLabFlow::TestCase
  def setup
    # Ensure we have sample reagents and equipment for field creation
    LabReagent.find_or_create_by!(name: 'Test Reagent', lot_number: 'TEST-LOT-001')
    LabEquipment.find_or_create_by!(name: 'Test Equipment', status: 'available')
  end

  # --- Workflow Status Tests ---

  test "install creates Accessioned status" do
    setup_lab_flow
    status = IssueStatus.find_by(name: I18n.t(:label_status_accessioned))

    assert_not_nil status
    assert_not status.is_closed
  end

  test "install creates In Analysis status" do
    setup_lab_flow
    status = IssueStatus.find_by(name: I18n.t(:label_status_in_analysis))

    assert_not_nil status
    assert_not status.is_closed
  end

  test "install creates QC Pending status" do
    setup_lab_flow
    status = IssueStatus.find_by(name: I18n.t(:label_status_qc_pending))

    assert_not_nil status
    assert_not status.is_closed
  end

  test "install creates Completed status as closed" do
    setup_lab_flow
    status = IssueStatus.find_by(name: I18n.t(:label_status_completed))

    assert_not_nil status
    assert status.is_closed
  end

  test "install does not duplicate workflow statuses" do
    setup_lab_flow
    initial_count = IssueStatus.count

    RedmineLabFlow::Setup.install
    assert_equal initial_count, IssueStatus.count
  end

  # --- Inventory Field Tests ---

  test "install creates Lot Number custom field" do
    setup_lab_flow
    field = IssueCustomField.find_by(name: I18n.t(:field_lot_number))

    assert_not_nil field
    assert_equal 'list', field.field_format
    assert field.is_filter
  end

  test "install creates Equipment ID custom field" do
    setup_lab_flow
    field = IssueCustomField.find_by(name: I18n.t(:field_equipment_id))

    assert_not_nil field
    assert_equal 'list', field.field_format
    assert field.is_filter
  end

  test "Lot Number field is associated with Assay tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_assay))
    field = IssueCustomField.find_by(name: I18n.t(:field_lot_number))

    assert_not_nil tracker
    assert_not_nil field
    assert_includes tracker.custom_fields, field
  end

  test "Equipment ID field is associated with Assay tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_assay))
    field = IssueCustomField.find_by(name: I18n.t(:field_equipment_id))

    assert_not_nil tracker
    assert_not_nil field
    assert_includes tracker.custom_fields, field
  end

  test "Equipment ID field is associated with Sample tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_sample))
    field = IssueCustomField.find_by(name: I18n.t(:field_equipment_id))

    assert_not_nil tracker
    assert_not_nil field
    assert_includes tracker.custom_fields, field
  end

  # --- Helper Method Tests ---

  test "assay_tracker returns the Assay tracker" do
    setup_lab_flow
    tracker = RedmineLabFlow::Setup.assay_tracker

    assert_not_nil tracker
    assert_equal I18n.t(:label_assay), tracker.name
  end

  test "sample_tracker returns the Sample tracker" do
    setup_lab_flow
    tracker = RedmineLabFlow::Setup.sample_tracker

    assert_not_nil tracker
    assert_equal I18n.t(:label_sample), tracker.name
  end

  test "completed_status returns the Completed status" do
    setup_lab_flow
    status = RedmineLabFlow::Setup.completed_status

    assert_not_nil status
    assert_equal I18n.t(:label_status_completed), status.name
  end
end
