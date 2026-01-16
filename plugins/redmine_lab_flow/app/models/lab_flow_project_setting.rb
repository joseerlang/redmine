# frozen_string_literal: true

class LabFlowProjectSetting < ApplicationRecord
  include Redmine::SafeAttributes

  belongs_to :project

  validates :project_id, presence: true, uniqueness: true

  safe_attributes 'allow_admin_unlock_finalized'

  # Find or initialize settings for a project
  def self.for_project(project)
    return new if project.nil?

    find_or_initialize_by(project: project)
  end

  # Check if admin can unlock finalized records for this project
  def admin_can_unlock?
    allow_admin_unlock_finalized
  end
end
