# frozen_string_literal: true

require_relative '../test_helper'

class LabEquipmentControllerTest < ActionController::TestCase
  fixtures :users

  def setup
    @controller = LabEquipmentController.new
    @request.session[:user_id] = 1 # admin
    LabEquipment.delete_all
  end

  # --- Index Tests ---

  test "index requires admin" do
    @request.session[:user_id] = 2 # non-admin
    get :index
    assert_response :forbidden
  end

  test "index redirects to plugin settings" do
    get :index
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=lab_equipment"
  end

  # --- New Tests ---

  test "new requires admin" do
    @request.session[:user_id] = 2 # non-admin
    get :new
    assert_response :forbidden
  end

  test "new renders form for admin" do
    get :new
    assert_response :success
    assert_select 'form'
    assert_select 'input[name="lab_equipment[name]"]'
  end

  test "new renders with fieldsets" do
    get :new
    assert_response :success
    assert_select 'fieldset.box.tabular'
    assert_select 'div.splitcontent'
  end

  # --- Create Tests ---

  test "create requires admin" do
    @request.session[:user_id] = 2 # non-admin
    post :create, params: {
      lab_equipment: { name: 'Test', status: 'available' }
    }
    assert_response :forbidden
  end

  test "create adds new equipment" do
    assert_difference 'LabEquipment.count', 1 do
      post :create, params: {
        lab_equipment: {
          name: 'New Equipment',
          serial_number: 'SN-NEW',
          status: 'available'
        }
      }
    end
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=lab_equipment"
    assert_equal 'New Equipment', LabEquipment.last.name
  end

  test "create with all fields" do
    assert_difference 'LabEquipment.count', 1 do
      post :create, params: {
        lab_equipment: {
          name: 'Complete Equipment',
          serial_number: 'SN-COMPLETE',
          model: 'Model X',
          manufacturer: 'Acme Inc',
          calibration_due: Date.today + 1.year,
          last_calibration: Date.today,
          location: 'Lab A',
          status: 'available',
          active: true
        }
      }
    end
    equipment = LabEquipment.last
    assert_equal 'Complete Equipment', equipment.name
    assert_equal 'SN-COMPLETE', equipment.serial_number
    assert_equal 'Model X', equipment.model
    assert_equal 'Acme Inc', equipment.manufacturer
    assert_equal 'Lab A', equipment.location
    assert_equal 'available', equipment.status
    assert equipment.active
  end

  test "create with invalid data renders new" do
    assert_no_difference 'LabEquipment.count' do
      post :create, params: {
        lab_equipment: {
          name: '',
          status: 'invalid'
        }
      }
    end
    assert_response :success
    assert_select 'div#errorExplanation', 1
  end

  # --- Edit Tests ---

  test "edit requires admin" do
    @request.session[:user_id] = 2 # non-admin
    equipment = LabEquipment.create!(name: 'Test', status: 'available')
    get :edit, params: { id: equipment.id }
    assert_response :forbidden
  end

  test "edit renders form for existing equipment" do
    equipment = LabEquipment.create!(name: 'Edit Me', status: 'available')
    get :edit, params: { id: equipment.id }
    assert_response :success
    assert_select 'form'
    assert_select 'input[name="lab_equipment[name]"][value="Edit Me"]'
  end

  test "edit with invalid id returns 404" do
    get :edit, params: { id: 99999 }
    assert_response :not_found
  end

  # --- Update Tests ---

  test "update requires admin" do
    @request.session[:user_id] = 2 # non-admin
    equipment = LabEquipment.create!(name: 'Test', status: 'available')
    patch :update, params: {
      id: equipment.id,
      lab_equipment: { name: 'New Name' }
    }
    assert_response :forbidden
  end

  test "update modifies equipment" do
    equipment = LabEquipment.create!(name: 'Old Name', status: 'available')
    patch :update, params: {
      id: equipment.id,
      lab_equipment: { name: 'New Name' }
    }
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=lab_equipment"
    equipment.reload
    assert_equal 'New Name', equipment.name
  end

  test "update with invalid data renders edit" do
    equipment = LabEquipment.create!(name: 'Valid', status: 'available')
    patch :update, params: {
      id: equipment.id,
      lab_equipment: { name: '' }
    }
    assert_response :success
    assert_select 'div#errorExplanation', 1
  end

  test "update with invalid id returns 404" do
    patch :update, params: {
      id: 99999,
      lab_equipment: { name: 'Test' }
    }
    assert_response :not_found
  end

  # --- Destroy Tests ---

  test "destroy requires admin" do
    @request.session[:user_id] = 2 # non-admin
    equipment = LabEquipment.create!(name: 'Test', status: 'available')
    delete :destroy, params: { id: equipment.id }
    assert_response :forbidden
  end

  test "destroy removes equipment" do
    equipment = LabEquipment.create!(name: 'Delete Me', status: 'available')
    assert_difference 'LabEquipment.count', -1 do
      delete :destroy, params: { id: equipment.id }
    end
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=lab_equipment"
  end

  test "destroy with invalid id returns 404" do
    delete :destroy, params: { id: 99999 }
    assert_response :not_found
  end

  # --- Calibration Status Tests ---

  test "equipment with overdue calibration" do
    equipment = LabEquipment.create!(
      name: 'Overdue Equipment',
      calibration_due: Date.today - 10.days,
      status: 'available'
    )
    assert equipment.calibration_overdue?
  end

  test "equipment with calibration due soon" do
    equipment = LabEquipment.create!(
      name: 'Due Soon Equipment',
      calibration_due: Date.today + 15.days,
      status: 'available'
    )
    assert equipment.calibration_due_soon?
    assert_not equipment.calibration_overdue?
  end

  test "equipment with current calibration" do
    equipment = LabEquipment.create!(
      name: 'Current Equipment',
      calibration_due: Date.today + 60.days,
      status: 'available'
    )
    assert_not equipment.calibration_overdue?
    assert_not equipment.calibration_due_soon?
  end
end
