# frozen_string_literal: true

class WikiTemplatesController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  accept_api_auth :index, :show

  def index
    @templates = LabFlowProcedureTemplate.active.sorted

    respond_to do |format|
      format.json do
        render json: @templates.map { |t| { id: t.id, name: t.name, description: t.description } }
      end
      format.html { render_404 }
    end
  end

  def show
    @template = LabFlowProcedureTemplate.find(params[:id])

    respond_to do |format|
      format.json do
        render json: {
          id: @template.id,
          name: @template.name,
          description: @template.description,
          content: @template.content
        }
      end
      format.html { render_404 }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not found' }, status: :not_found
  end
end
