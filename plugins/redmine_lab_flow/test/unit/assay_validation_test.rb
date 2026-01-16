# frozen_string_literal: true

require_relative '../test_helper'

class AssayValidationTest < RedmineLabFlow::TestCase
  fixtures :projects, :users, :issue_statuses, :trackers, :enumerations

  def setup
    setup_lab_flow
    @project = Project.find(1)
    @project.enable_module!(:laboratory_management)

    # Ensure assay tracker exists and is associated with project
    if @assay_tracker
      @project.trackers << @assay_tracker unless @project.trackers.include?(@assay_tracker)
    end

    @admin = User.find(1)
    @default_priority = IssuePriority.default || IssuePriority.first

    # Clean up
    LabReagent.delete_all
    LabEquipment.delete_all
  end

  def skip_if_no_assay_tracker
    skip "Assay tracker not available" unless @assay_tracker
  end

  # --- Expired Reagent Validation Tests ---

  test "assay cannot be completed with expired reagent" do
    skip_if_no_assay_tracker

    # Create expired reagent
    expired_reagent = LabReagent.create!(
      name: 'Expired Reagent',
      lot_number: 'EXP-001',
      expiration_date: Date.today - 1.day
    )

    # Update lot number field with reagent
    RedmineLabFlow::Setup.install
    lot_field = IssueCustomField.find_by(name: I18n.t(:field_lot_number))
    lot_field.possible_values = [expired_reagent.display_name]
    lot_field.save!

    # Get completed status
    completed_status = IssueStatus.find_by(name: I18n.t(:label_status_completed))
    default_status = IssueStatus.sorted.first

    # Create assay with expired reagent
    assay = Issue.new(
      project: @project,
      tracker: @assay_tracker,
      status: default_status,
      priority: @default_priority,
      author: @admin,
      subject: 'Test Assay'
    )
    assay.custom_field_values = { lot_field.id => expired_reagent.display_name }
    assay.save!

    # Try to complete the assay
    assay.status = completed_status
    assert_not assay.valid?
    assert assay.errors[:base].any? { |e| e.include?('expired') }
  end

  test "assay can be completed with valid reagent" do
    skip_if_no_assay_tracker

    # Create valid reagent
    valid_reagent = LabReagent.create!(
      name: 'Valid Reagent',
      lot_number: 'VAL-001',
      expiration_date: Date.today + 1.year
    )

    # Update lot number field with reagent
    RedmineLabFlow::Setup.install
    lot_field = IssueCustomField.find_by(name: I18n.t(:field_lot_number))
    lot_field.possible_values = [valid_reagent.display_name]
    lot_field.save!

    # Get completed status
    completed_status = IssueStatus.find_by(name: I18n.t(:label_status_completed))
    default_status = IssueStatus.sorted.first

    # Create assay with valid reagent
    assay = Issue.new(
      project: @project,
      tracker: @assay_tracker,
      status: default_status,
      priority: @default_priority,
      author: @admin,
      subject: 'Test Assay Valid'
    )
    assay.custom_field_values = { lot_field.id => valid_reagent.display_name }
    assay.save!

    # Complete the assay
    assay.status = completed_status
    # Note: May need notes for audit compliance
    assay.init_journal(@admin, 'Completing assay')
    assert assay.valid?, "Assay should be valid: #{assay.errors.full_messages}"
  end

  test "assay can be completed without reagent" do
    skip_if_no_assay_tracker

    completed_status = IssueStatus.find_by(name: I18n.t(:label_status_completed))
    default_status = IssueStatus.sorted.first

    # Create assay without reagent
    assay = Issue.new(
      project: @project,
      tracker: @assay_tracker,
      status: default_status,
      priority: @default_priority,
      author: @admin,
      subject: 'Test Assay No Reagent'
    )
    assay.save!

    # Complete the assay
    assay.status = completed_status
    assay.init_journal(@admin, 'Completing without reagent')

    # Should not have expired reagent error
    assay.valid?
    assert_not assay.errors[:base].any? { |e| e.include?('expired') }
  end
end
