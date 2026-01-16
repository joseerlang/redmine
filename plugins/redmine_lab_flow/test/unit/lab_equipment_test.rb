# frozen_string_literal: true

require_relative '../test_helper'

class LabEquipmentTest < RedmineLabFlow::TestCase
  def setup
    LabEquipment.delete_all
  end

  # --- Validation Tests ---

  test "equipment requires name" do
    equipment = LabEquipment.new(status: 'available')
    assert_not equipment.valid?
    assert equipment.errors[:name].any?
  end

  test "serial_number must be unique when present" do
    LabEquipment.create!(name: 'Equipment 1', serial_number: 'SN-001', status: 'available')
    equipment = LabEquipment.new(name: 'Equipment 2', serial_number: 'SN-001', status: 'available')

    assert_not equipment.valid?
    assert_includes equipment.errors[:serial_number], "has already been taken"
  end

  test "serial_number can be blank" do
    equipment = LabEquipment.new(name: 'No Serial', status: 'available')
    assert equipment.valid?
  end

  test "status must be valid" do
    equipment = LabEquipment.new(name: 'Test', status: 'invalid_status')
    assert_not equipment.valid?
    assert_includes equipment.errors[:status], "is not included in the list"
  end

  test "all valid statuses are accepted" do
    LabEquipment::STATUSES.each_with_index do |status, idx|
      equipment = LabEquipment.new(name: "Equipment #{idx}", serial_number: "SN-#{idx}", status: status)
      assert equipment.valid?, "Status '#{status}' should be valid"
    end
  end

  # --- Calibration Tests ---

  test "calibration_overdue? returns true for past calibration due date" do
    equipment = LabEquipment.create!(
      name: 'Overdue Equipment',
      calibration_due: Date.today - 1.day,
      status: 'available'
    )

    assert equipment.calibration_overdue?
  end

  test "calibration_overdue? returns false for future calibration due date" do
    equipment = LabEquipment.create!(
      name: 'Calibrated Equipment',
      calibration_due: Date.today + 1.year,
      status: 'available'
    )

    assert_not equipment.calibration_overdue?
  end

  test "calibration_overdue? returns false when no calibration due date" do
    equipment = LabEquipment.create!(
      name: 'No Calibration',
      status: 'available'
    )

    assert_not equipment.calibration_overdue?
  end

  test "calibration_due_soon? returns true when within 30 days" do
    equipment = LabEquipment.create!(
      name: 'Due Soon',
      calibration_due: Date.today + 15.days,
      status: 'available'
    )

    assert equipment.calibration_due_soon?
  end

  test "calibration_due_soon? returns false when beyond 30 days" do
    equipment = LabEquipment.create!(
      name: 'Not Due Soon',
      calibration_due: Date.today + 60.days,
      status: 'available'
    )

    assert_not equipment.calibration_due_soon?
  end

  # --- Scope Tests ---

  test "active scope returns only active equipment" do
    LabEquipment.create!(name: 'Active', status: 'available', active: true)
    LabEquipment.create!(name: 'Inactive', status: 'available', active: false)

    assert_equal 1, LabEquipment.active.count
    assert_equal 'Active', LabEquipment.active.first.name
  end

  test "available scope returns only available active equipment" do
    LabEquipment.create!(name: 'Available', status: 'available', active: true)
    LabEquipment.create!(name: 'In Use', status: 'in_use', active: true)
    LabEquipment.create!(name: 'Inactive Available', status: 'available', active: false)

    assert_equal 1, LabEquipment.available.count
    assert_equal 'Available', LabEquipment.available.first.name
  end

  test "calibration_overdue scope returns overdue equipment" do
    LabEquipment.create!(name: 'Overdue', calibration_due: Date.today - 1.day, status: 'available')
    LabEquipment.create!(name: 'Current', calibration_due: Date.today + 1.year, status: 'available')

    assert_equal 1, LabEquipment.calibration_overdue.count
    assert_equal 'Overdue', LabEquipment.calibration_overdue.first.name
  end

  test "calibration_due_soon scope returns equipment due within days" do
    LabEquipment.create!(name: 'Soon', calibration_due: Date.today + 10.days, status: 'available')
    LabEquipment.create!(name: 'Later', calibration_due: Date.today + 60.days, status: 'available')

    assert_equal 1, LabEquipment.calibration_due_soon(30).count
    assert_equal 'Soon', LabEquipment.calibration_due_soon(30).first.name
  end

  # --- Display Tests ---

  test "display_name includes name and serial number when present" do
    equipment = LabEquipment.create!(name: 'pH Meter', serial_number: 'SN-123', status: 'available')

    assert_equal 'pH Meter (S/N: SN-123)', equipment.display_name
  end

  test "display_name shows only name when no serial number" do
    equipment = LabEquipment.create!(name: 'Generic Tool', status: 'available')

    assert_equal 'Generic Tool', equipment.display_name
  end
end
