# frozen_string_literal: true

class LabReagent < ActiveRecord::Base
  include Redmine::SafeAttributes

  validates :name, presence: true
  validates :lot_number, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :expired, -> { where('expiration_date < ?', Date.current) }
  scope :expiring_soon, ->(days = 30) { where('expiration_date BETWEEN ? AND ?', Date.current, Date.current + days.days) }
  scope :sorted, -> { order(:name) }

  safe_attributes 'name', 'lot_number', 'expiration_date', 'quantity', 'unit',
                  'supplier', 'catalog_number', 'storage_conditions', 'active'

  def expired?
    expiration_date.present? && expiration_date < Date.current
  end

  def expiring_soon?(days = 30)
    return false if expiration_date.blank?

    expiration_date >= Date.current && expiration_date <= Date.current + days.days
  end

  def display_name
    "#{name} (Lot: #{lot_number})"
  end

  def status_label
    if expired?
      I18n.t(:label_expired)
    elsif expiring_soon?
      I18n.t(:label_expiring_soon)
    else
      I18n.t(:label_valid)
    end
  end
end
