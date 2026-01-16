# frozen_string_literal: true

# Load the Redmine test helper
require File.expand_path('../../../../test/test_helper', __FILE__)

module RedmineLabFlow
  class TestCase < ActiveSupport::TestCase
    # Common setup for all lab flow tests
    def setup_lab_flow
      # Ensure plugin is loaded
      require_relative '../lib/redmine_lab_flow/setup'
      RedmineLabFlow::Setup.install

      # Get trackers
      @sample_tracker = Tracker.find_by(name: I18n.t(:label_sample))
      @daily_log_tracker = Tracker.find_by(name: I18n.t(:label_daily_log))
      @assay_tracker = Tracker.find_by(name: I18n.t(:label_assay))
    end

    def enable_lab_module_for(project)
      project.enable_module!(:laboratory_management)
    end
  end
end
