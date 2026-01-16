# frozen_string_literal: true

class LabFlowSettingsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  def update
    @settings = LabFlowProjectSetting.for_project(@project)
    @settings.safe_attributes = params[:lab_flow_project_setting]

    if @settings.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = @settings.errors.full_messages.join(', ')
    end

    redirect_to settings_project_path(@project, tab: 'lab_flow')
  end
end
