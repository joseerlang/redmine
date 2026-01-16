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

  test "index renders successfully for admin" do
    get :index
    assert_response :success
  end

  test "index shows equipment list" do
    LabEquipment.create!(name: 'Test Equipment', status: 'available')
    get :index
    assert_response :success
    assert_select 'table.list tbody tr', 1
  end

  test "index shows calibration overdue warning" do
    LabEquipment.create!(name: 'Overdue', calibration_due: Date.today - 1.day, status: 'available')
    get :index
    assert_response :success
    assert_select 'div.flash.warning'
  end

  # --- New Tests ---

  test "new renders form for admin" do
    get :new
    assert_response :success
  end

  # --- Create Tests ---

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
    assert_redirected_to lab_equipment_index_path
    assert_equal 'New Equipment', LabEquipment.last.name
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
  end

  # --- Edit Tests ---

  test "edit renders form for existing equipment" do
    equipment = LabEquipment.create!(name: 'Edit Me', status: 'available')
    get :edit, params: { id: equipment.id }
    assert_response :success
  end

  test "edit with invalid id returns 404" do
    get :edit, params: { id: 99999 }
    assert_response :not_found
  end

  # --- Update Tests ---

  test "update modifies equipment" do
    equipment = LabEquipment.create!(name: 'Old Name', status: 'available')
    patch :update, params: {
      id: equipment.id,
      lab_equipment: { name: 'New Name' }
    }
    assert_redirected_to lab_equipment_index_path
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
  end

  # --- Destroy Tests ---

  test "destroy removes equipment" do
    equipment = LabEquipment.create!(name: 'Delete Me', status: 'available')
    assert_difference 'LabEquipment.count', -1 do
      delete :destroy, params: { id: equipment.id }
    end
    assert_redirected_to lab_equipment_index_path
  end
end
