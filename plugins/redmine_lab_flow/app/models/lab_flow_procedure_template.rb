# frozen_string_literal: true

class LabFlowProcedureTemplate < ApplicationRecord
  include Redmine::SafeAttributes

  acts_as_positioned

  validates :name, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :content, presence: true

  scope :active, -> { where(active: true) }
  scope :sorted, -> { order(:position, :name) }

  safe_attributes 'name', 'description', 'content', 'active', 'position'

  def to_s
    name
  end
end
