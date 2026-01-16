# frozen_string_literal: true

require_relative '../test_helper'

class ProcedureTemplatesControllerTest < ActionController::TestCase
  fixtures :users

  def setup
    @controller = ProcedureTemplatesController.new
    @request.session[:user_id] = 1 # admin
    LabFlowProcedureTemplate.delete_all
  end

  # --- Index Tests ---

  test "index requires admin" do
    @request.session[:user_id] = 2 # non-admin
    get :index
    assert_response :forbidden
  end

  test "index redirects to plugin settings" do
    get :index
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=procedure_templates"
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
    # labelled_form_for uses the model class name
    assert_select 'input[name="lab_flow_procedure_template[name]"]'
  end

  # --- Create Tests ---

  test "create requires admin" do
    @request.session[:user_id] = 2 # non-admin
    post :create, params: {
      procedure_template: { name: 'Test', content: 'Content' }
    }
    assert_response :forbidden
  end

  test "create adds new template" do
    assert_difference 'LabFlowProcedureTemplate.count', 1 do
      post :create, params: {
        procedure_template: {
          name: 'New Template',
          description: 'A test template',
          content: '# Template Content',
          active: true
        }
      }
    end
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=procedure_templates"
    template = LabFlowProcedureTemplate.last
    assert_equal 'New Template', template.name
    assert_equal 'A test template', template.description
    assert_equal '# Template Content', template.content
    assert template.active
  end

  test "create with invalid data renders new" do
    assert_no_difference 'LabFlowProcedureTemplate.count' do
      post :create, params: {
        procedure_template: {
          name: '',
          content: ''
        }
      }
    end
    assert_response :success
  end

  # --- Show Tests (JSON API) ---

  test "show returns JSON for template" do
    template = LabFlowProcedureTemplate.create!(
      name: 'JSON Template',
      content: '# Content'
    )
    get :show, params: { id: template.id }, format: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal template.id, json['id']
    assert_equal 'JSON Template', json['name']
    assert_equal '# Content', json['content']
  end

  test "show with invalid id returns 404" do
    get :show, params: { id: 99999 }, format: :json
    assert_response :not_found
  end

  # --- Edit Tests ---

  test "edit requires admin" do
    @request.session[:user_id] = 2 # non-admin
    template = LabFlowProcedureTemplate.create!(name: 'Test', content: 'Content')
    get :edit, params: { id: template.id }
    assert_response :forbidden
  end

  test "edit renders form for existing template" do
    template = LabFlowProcedureTemplate.create!(name: 'Edit Me', content: '# Content')
    get :edit, params: { id: template.id }
    assert_response :success
    assert_select 'form'
    assert_select 'input[name="lab_flow_procedure_template[name]"][value="Edit Me"]'
  end

  test "edit with invalid id returns 404" do
    get :edit, params: { id: 99999 }
    assert_response :not_found
  end

  # --- Update Tests ---

  test "update requires admin" do
    @request.session[:user_id] = 2 # non-admin
    template = LabFlowProcedureTemplate.create!(name: 'Test', content: 'Content')
    patch :update, params: {
      id: template.id,
      procedure_template: { name: 'New Name' }
    }
    assert_response :forbidden
  end

  test "update modifies template" do
    template = LabFlowProcedureTemplate.create!(name: 'Old Name', content: '# Old')
    patch :update, params: {
      id: template.id,
      procedure_template: { name: 'New Name', content: '# New' }
    }
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=procedure_templates"
    template.reload
    assert_equal 'New Name', template.name
    assert_equal '# New', template.content
  end

  test "update with invalid data renders edit" do
    template = LabFlowProcedureTemplate.create!(name: 'Valid', content: '# Content')
    patch :update, params: {
      id: template.id,
      procedure_template: { name: '' }
    }
    assert_response :success
  end

  test "update with invalid id returns 404" do
    patch :update, params: {
      id: 99999,
      procedure_template: { name: 'Test' }
    }
    assert_response :not_found
  end

  # --- Destroy Tests ---

  test "destroy requires admin" do
    @request.session[:user_id] = 2 # non-admin
    template = LabFlowProcedureTemplate.create!(name: 'Test', content: 'Content')
    delete :destroy, params: { id: template.id }
    assert_response :forbidden
  end

  test "destroy removes template" do
    template = LabFlowProcedureTemplate.create!(name: 'Delete Me', content: '# Content')
    assert_difference 'LabFlowProcedureTemplate.count', -1 do
      delete :destroy, params: { id: template.id }
    end
    assert_redirected_to "/settings/plugin/redmine_lab_flow?tab=procedure_templates"
  end

  test "destroy with invalid id returns 404" do
    delete :destroy, params: { id: 99999 }
    assert_response :not_found
  end

  # --- Model Tests ---

  test "template requires name" do
    template = LabFlowProcedureTemplate.new(content: '# Content')
    assert_not template.valid?
    assert template.errors[:name].any?
  end

  test "template requires content" do
    template = LabFlowProcedureTemplate.new(name: 'Test')
    assert_not template.valid?
    assert template.errors[:content].any?
  end

  test "template name must be unique" do
    LabFlowProcedureTemplate.create!(name: 'Unique', content: '# Content')
    duplicate = LabFlowProcedureTemplate.new(name: 'Unique', content: '# Other')
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "template defaults to active" do
    template = LabFlowProcedureTemplate.create!(name: 'Active Test', content: '# Content')
    assert template.active
  end

  test "template sorted scope orders by position" do
    # acts_as_positioned auto-assigns positions, so we need to update them after creation
    t1 = LabFlowProcedureTemplate.create!(name: 'Template 1', content: '#1')
    t2 = LabFlowProcedureTemplate.create!(name: 'Template 2', content: '#2')
    t3 = LabFlowProcedureTemplate.create!(name: 'Template 3', content: '#3')

    # Update positions manually
    t1.update_column(:position, 2)
    t2.update_column(:position, 1)
    t3.update_column(:position, 3)

    sorted = LabFlowProcedureTemplate.sorted.to_a
    assert_equal [t2, t1, t3], sorted
  end
end
