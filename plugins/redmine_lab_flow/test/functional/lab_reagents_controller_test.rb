# frozen_string_literal: true

require_relative '../test_helper'

class LabReagentsControllerTest < ActionController::TestCase
  fixtures :users

  def setup
    @controller = LabReagentsController.new
    @request.session[:user_id] = 1 # admin
    LabReagent.delete_all
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

  test "index shows reagent list" do
    LabReagent.create!(name: 'Test Reagent', lot_number: 'LOT-001')
    get :index
    assert_response :success
    assert_select 'table.list tbody tr', 1
  end

  test "index shows expired count warning" do
    LabReagent.create!(name: 'Expired', lot_number: 'LOT-EXP', expiration_date: Date.today - 1.day)
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

  test "create adds new reagent" do
    assert_difference 'LabReagent.count', 1 do
      post :create, params: {
        lab_reagent: {
          name: 'New Reagent',
          lot_number: 'LOT-NEW',
          expiration_date: Date.today + 1.year
        }
      }
    end
    assert_redirected_to lab_reagents_path
    assert_equal 'New Reagent', LabReagent.last.name
  end

  test "create with invalid data renders new" do
    assert_no_difference 'LabReagent.count' do
      post :create, params: {
        lab_reagent: {
          name: '',
          lot_number: ''
        }
      }
    end
    assert_response :success
  end

  # --- Edit Tests ---

  test "edit renders form for existing reagent" do
    reagent = LabReagent.create!(name: 'Edit Me', lot_number: 'LOT-EDIT')
    get :edit, params: { id: reagent.id }
    assert_response :success
  end

  test "edit with invalid id returns 404" do
    get :edit, params: { id: 99999 }
    assert_response :not_found
  end

  # --- Update Tests ---

  test "update modifies reagent" do
    reagent = LabReagent.create!(name: 'Old Name', lot_number: 'LOT-UPD')
    patch :update, params: {
      id: reagent.id,
      lab_reagent: { name: 'New Name' }
    }
    assert_redirected_to lab_reagents_path
    reagent.reload
    assert_equal 'New Name', reagent.name
  end

  test "update with invalid data renders edit" do
    reagent = LabReagent.create!(name: 'Valid', lot_number: 'LOT-VAL')
    patch :update, params: {
      id: reagent.id,
      lab_reagent: { name: '' }
    }
    assert_response :success
  end

  # --- Destroy Tests ---

  test "destroy removes reagent" do
    reagent = LabReagent.create!(name: 'Delete Me', lot_number: 'LOT-DEL')
    assert_difference 'LabReagent.count', -1 do
      delete :destroy, params: { id: reagent.id }
    end
    assert_redirected_to lab_reagents_path
  end
end
