# frozen_string_literal: true

class LabEquipment < ActiveRecord::Base
  self.table_name = 'lab_equipment'

  include Redmine::SafeAttributes

  STATUSES = %w[available in_use maintenance out_of_service].freeze

  validates :name, presence: true
  validates :serial_number, uniqueness: true, allow_blank: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(active: true) }
  scope :available, -> { active.where(status: 'available') }
  scope :calibration_due_soon, ->(days = 30) { where('calibration_due BETWEEN ? AND ?', Date.current, Date.current + days.days) }
  scope :calibration_overdue, -> { where('calibration_due < ?', Date.current) }
  scope :sorted, -> { order(:name) }

  safe_attributes 'name', 'serial_number', 'model', 'manufacturer', 'calibration_due',
                  'last_calibration', 'location', 'status', 'active'

  def calibration_overdue?
    calibration_due.present? && calibration_due < Date.current
  end

  def calibration_due_soon?(days = 30)
    return false if calibration_due.blank?

    calibration_due >= Date.current && calibration_due <= Date.current + days.days
  end

  def display_name
    serial_number.present? ? "#{name} (S/N: #{serial_number})" : name
  end

  def status_label
    I18n.t("label_equipment_status_#{status}", default: status.humanize)
  end

  def calibration_status_label
    if calibration_overdue?
      I18n.t(:label_calibration_overdue)
    elsif calibration_due_soon?
      I18n.t(:label_calibration_due_soon)
    else
      I18n.t(:label_calibration_current)
    end
  end
end
