# frozen_string_literal: true

require_relative '../test_helper'

class LabReagentTest < RedmineLabFlow::TestCase
  def setup
    # Clean up any existing test data
    LabReagent.delete_all
  end

  # --- Validation Tests ---

  test "reagent requires name" do
    reagent = LabReagent.new(lot_number: 'LOT-001')
    assert_not reagent.valid?
    assert reagent.errors[:name].any?
  end

  test "reagent requires lot_number" do
    reagent = LabReagent.new(name: 'Test Reagent')
    assert_not reagent.valid?
    assert reagent.errors[:lot_number].any?
  end

  test "lot_number must be unique" do
    LabReagent.create!(name: 'Reagent 1', lot_number: 'LOT-001')
    reagent = LabReagent.new(name: 'Reagent 2', lot_number: 'LOT-001')

    assert_not reagent.valid?
    assert_includes reagent.errors[:lot_number], "has already been taken"
  end

  test "valid reagent can be saved" do
    reagent = LabReagent.new(
      name: 'Test Reagent',
      lot_number: 'LOT-002',
      expiration_date: Date.today + 1.year
    )

    assert reagent.valid?
    assert reagent.save
  end

  # --- Expiration Tests ---

  test "expired? returns true for past expiration date" do
    reagent = LabReagent.create!(
      name: 'Expired Reagent',
      lot_number: 'LOT-EXP',
      expiration_date: Date.today - 1.day
    )

    assert reagent.expired?
  end

  test "expired? returns false for future expiration date" do
    reagent = LabReagent.create!(
      name: 'Valid Reagent',
      lot_number: 'LOT-VALID',
      expiration_date: Date.today + 1.year
    )

    assert_not reagent.expired?
  end

  test "expired? returns false when no expiration date" do
    reagent = LabReagent.create!(
      name: 'No Expiration',
      lot_number: 'LOT-NOEXP'
    )

    assert_not reagent.expired?
  end

  test "expiring_soon? returns true when within 30 days" do
    reagent = LabReagent.create!(
      name: 'Expiring Soon',
      lot_number: 'LOT-SOON',
      expiration_date: Date.today + 15.days
    )

    assert reagent.expiring_soon?
  end

  test "expiring_soon? returns false when beyond 30 days" do
    reagent = LabReagent.create!(
      name: 'Not Expiring Soon',
      lot_number: 'LOT-LATER',
      expiration_date: Date.today + 60.days
    )

    assert_not reagent.expiring_soon?
  end

  # --- Scope Tests ---

  test "active scope returns only active reagents" do
    LabReagent.create!(name: 'Active', lot_number: 'LOT-ACT', active: true)
    LabReagent.create!(name: 'Inactive', lot_number: 'LOT-INACT', active: false)

    assert_equal 1, LabReagent.active.count
    assert_equal 'Active', LabReagent.active.first.name
  end

  test "expired scope returns only expired reagents" do
    LabReagent.create!(name: 'Expired', lot_number: 'LOT-E', expiration_date: Date.today - 1.day)
    LabReagent.create!(name: 'Valid', lot_number: 'LOT-V', expiration_date: Date.today + 1.year)

    assert_equal 1, LabReagent.expired.count
    assert_equal 'Expired', LabReagent.expired.first.name
  end

  test "expiring_soon scope returns reagents expiring within days" do
    LabReagent.create!(name: 'Soon', lot_number: 'LOT-S', expiration_date: Date.today + 10.days)
    LabReagent.create!(name: 'Later', lot_number: 'LOT-L', expiration_date: Date.today + 60.days)

    assert_equal 1, LabReagent.expiring_soon(30).count
    assert_equal 'Soon', LabReagent.expiring_soon(30).first.name
  end

  # --- Display Tests ---

  test "display_name includes name and lot number" do
    reagent = LabReagent.create!(name: 'Acetic Acid', lot_number: 'LOT-123')

    assert_equal 'Acetic Acid (Lot: LOT-123)', reagent.display_name
  end
end
