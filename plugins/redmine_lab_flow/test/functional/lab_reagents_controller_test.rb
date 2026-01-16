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

  test "index redirects to plugin settings" do
    get :index
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=lab_reagents"
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
    assert_select 'input[name="lab_reagent[name]"]'
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
      lab_reagent: { name: 'Test', lot_number: 'LOT-001' }
    }
    assert_response :forbidden
  end

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
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=lab_reagents"
    assert_equal 'New Reagent', LabReagent.last.name
  end

  test "create with all fields" do
    assert_difference 'LabReagent.count', 1 do
      post :create, params: {
        lab_reagent: {
          name: 'Complete Reagent',
          lot_number: 'LOT-COMPLETE',
          expiration_date: Date.today + 1.year,
          quantity: '500',
          unit: 'mL',
          supplier: 'Sigma Aldrich',
          catalog_number: 'CAT-12345',
          storage_conditions: '2-8°C',
          active: true
        }
      }
    end
    reagent = LabReagent.last
    assert_equal 'Complete Reagent', reagent.name
    assert_equal 'LOT-COMPLETE', reagent.lot_number
    assert_equal 'Sigma Aldrich', reagent.supplier
    assert_equal 'CAT-12345', reagent.catalog_number
    assert_equal '2-8°C', reagent.storage_conditions
    assert reagent.active
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
    assert_select 'div#errorExplanation', 1
  end

  # --- Edit Tests ---

  test "edit requires admin" do
    @request.session[:user_id] = 2 # non-admin
    reagent = LabReagent.create!(name: 'Test', lot_number: 'LOT-001')
    get :edit, params: { id: reagent.id }
    assert_response :forbidden
  end

  test "edit renders form for existing reagent" do
    reagent = LabReagent.create!(name: 'Edit Me', lot_number: 'LOT-EDIT')
    get :edit, params: { id: reagent.id }
    assert_response :success
    assert_select 'form'
    assert_select 'input[name="lab_reagent[name]"][value="Edit Me"]'
  end

  test "edit with invalid id returns 404" do
    get :edit, params: { id: 99999 }
    assert_response :not_found
  end

  # --- Update Tests ---

  test "update requires admin" do
    @request.session[:user_id] = 2 # non-admin
    reagent = LabReagent.create!(name: 'Test', lot_number: 'LOT-001')
    patch :update, params: {
      id: reagent.id,
      lab_reagent: { name: 'New Name' }
    }
    assert_response :forbidden
  end

  test "update modifies reagent" do
    reagent = LabReagent.create!(name: 'Old Name', lot_number: 'LOT-UPD')
    patch :update, params: {
      id: reagent.id,
      lab_reagent: { name: 'New Name' }
    }
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=lab_reagents"
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
    assert_select 'div#errorExplanation', 1
  end

  test "update with invalid id returns 404" do
    patch :update, params: {
      id: 99999,
      lab_reagent: { name: 'Test' }
    }
    assert_response :not_found
  end

  # --- Destroy Tests ---

  test "destroy requires admin" do
    @request.session[:user_id] = 2 # non-admin
    reagent = LabReagent.create!(name: 'Test', lot_number: 'LOT-001')
    delete :destroy, params: { id: reagent.id }
    assert_response :forbidden
  end

  test "destroy removes reagent" do
    reagent = LabReagent.create!(name: 'Delete Me', lot_number: 'LOT-DEL')
    assert_difference 'LabReagent.count', -1 do
      delete :destroy, params: { id: reagent.id }
    end
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=lab_reagents"
  end

  test "destroy with invalid id returns 404" do
    delete :destroy, params: { id: 99999 }
    assert_response :not_found
  end

  # --- Expiration Status Tests ---

  test "reagent with expired date" do
    reagent = LabReagent.create!(
      name: 'Expired Reagent',
      lot_number: 'LOT-EXP',
      expiration_date: Date.today - 10.days
    )
    assert reagent.expired?
  end

  test "reagent expiring soon" do
    reagent = LabReagent.create!(
      name: 'Expiring Soon Reagent',
      lot_number: 'LOT-SOON',
      expiration_date: Date.today + 15.days
    )
    assert reagent.expiring_soon?
    assert_not reagent.expired?
  end

  test "reagent with valid expiration" do
    reagent = LabReagent.create!(
      name: 'Valid Reagent',
      lot_number: 'LOT-VALID',
      expiration_date: Date.today + 60.days
    )
    assert_not reagent.expired?
    assert_not reagent.expiring_soon?
  end

  test "reagent without expiration date is not expired" do
    reagent = LabReagent.create!(
      name: 'No Expiration',
      lot_number: 'LOT-NOEXP'
    )
    assert_not reagent.expired?
    assert_not reagent.expiring_soon?
  end
end
