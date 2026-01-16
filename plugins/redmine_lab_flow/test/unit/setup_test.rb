# frozen_string_literal: true

require_relative '../test_helper'

class SetupTest < RedmineLabFlow::TestCase
  def setup
    @original_tracker_count = Tracker.count
    @original_custom_field_count = IssueCustomField.count
  end

  # --- Tracker Creation Tests ---

  test "install creates Sample tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_sample))

    assert_not_nil tracker
    assert_equal I18n.t(:tracker_sample_description), tracker.description
    assert_not_nil tracker.default_status_id
  end

  test "install creates Daily Log tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_daily_log))

    assert_not_nil tracker
    assert_equal I18n.t(:tracker_daily_log_description), tracker.description
  end

  test "install creates Assay tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_assay))

    assert_not_nil tracker
    assert_equal I18n.t(:tracker_assay_description), tracker.description
  end

  test "install does not duplicate trackers on multiple runs" do
    setup_lab_flow
    initial_count = Tracker.count

    RedmineLabFlow::Setup.install
    assert_equal initial_count, Tracker.count
  end

  # --- Custom Field Creation Tests ---

  test "install creates Internal ID custom field for Sample" do
    setup_lab_flow
    field = IssueCustomField.find_by(name: I18n.t(:field_internal_id))

    assert_not_nil field
    assert_equal 'string', field.field_format
    assert field.is_required
    assert field.is_filter
    assert field.searchable
  end

  test "install creates Measured Value custom field for Assay" do
    setup_lab_flow
    field = IssueCustomField.find_by(name: I18n.t(:field_measured_value))

    assert_not_nil field
    assert_equal 'float', field.field_format
    assert field.is_required
  end

  test "install creates Unit custom field with configurable values" do
    Setting.plugin_redmine_lab_flow = { 'units' => "mg\nml\ng" }
    setup_lab_flow
    field = IssueCustomField.find_by(name: I18n.t(:field_unit))

    assert_not_nil field
    assert_equal 'list', field.field_format
    assert_includes field.possible_values, 'mg'
    assert_includes field.possible_values, 'ml'
    assert_includes field.possible_values, 'g'
  end

  test "install creates Experiment Reference custom field for Daily Log" do
    setup_lab_flow
    field = IssueCustomField.find_by(name: I18n.t(:field_experiment_reference))

    assert_not_nil field
    assert_equal 'string', field.field_format
    assert field.is_required
    assert field.searchable
  end

  test "install creates all Daily Log fields" do
    setup_lab_flow

    daily_log_fields = [
      :field_experiment_reference,
      :field_lab_conditions,
      :field_equipment_used,
      :field_observations,
      :field_protocol_version,
      :field_reviewed_by,
      :field_weather_conditions,
      :field_start_time,
      :field_end_time
    ]

    daily_log_fields.each do |field_key|
      field = IssueCustomField.find_by(name: I18n.t(field_key))
      assert_not_nil field, "Expected field #{field_key} to exist"
    end
  end

  test "install does not duplicate custom fields on multiple runs" do
    setup_lab_flow
    initial_count = IssueCustomField.count

    RedmineLabFlow::Setup.install
    assert_equal initial_count, IssueCustomField.count
  end

  # --- Field-Tracker Association Tests ---

  test "Internal ID field is associated with Sample tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_sample))
    field = IssueCustomField.find_by(name: I18n.t(:field_internal_id))

    assert_includes tracker.custom_fields, field
  end

  test "Measured Value field is associated with Assay tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_assay))
    field = IssueCustomField.find_by(name: I18n.t(:field_measured_value))

    assert_includes tracker.custom_fields, field
  end

  test "Unit field is associated with Assay tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_assay))
    field = IssueCustomField.find_by(name: I18n.t(:field_unit))

    assert_includes tracker.custom_fields, field
  end

  test "Experiment Reference field is associated with Daily Log tracker" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_daily_log))
    field = IssueCustomField.find_by(name: I18n.t(:field_experiment_reference))

    assert_includes tracker.custom_fields, field
  end

  test "Sample tracker has all expected custom fields" do
    setup_lab_flow
    tracker = Tracker.find_by(name: I18n.t(:label_sample))

    expected_fields = [
      :field_internal_id,
      :field_sample_type,
      :field_storage_location,
      :field_collection_date,
      :field_expiration_date,
      :field_sample_source
    ]

    expected_fields.each do |field_key|
      field = IssueCustomField.find_by(name: I18n.t(field_key))
      assert_includes tracker.custom_fields, field, "Expected #{field_key} to be associated with Sample tracker"
    end
  end
end
