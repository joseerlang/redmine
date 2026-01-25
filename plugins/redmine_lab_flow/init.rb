# frozen_string_literal: true

# Load helpers and patches
require_relative 'lib/redmine_lab_flow/helpers'
require_relative 'lib/redmine_lab_flow/hooks'
require_relative 'lib/redmine_lab_flow/issue_patch'
require_relative 'lib/redmine_lab_flow/wiki_reference_format'

# Phase 5 & 6 services
require_relative 'lib/redmine_lab_flow/metrics_calculator'
require_relative 'lib/redmine_lab_flow/report_generator'
require_relative 'lib/redmine_lab_flow/pdf_generator'
require_relative 'lib/redmine_lab_flow/excel_generator'
require_relative 'lib/redmine_lab_flow/json_exporter'
require_relative 'lib/redmine_lab_flow/webhook_dispatcher'
require_relative 'lib/redmine_lab_flow/galaxy_client'
require_relative 'lib/redmine_lab_flow/openbis_client'
require_relative 'lib/redmine_lab_flow/generic_client'
require_relative 'lib/redmine_lab_flow/fair_exporter'
require_relative 'lib/redmine_lab_flow/ontology_mapper'
require_relative 'lib/redmine_lab_flow/doi_minter'
require_relative 'lib/redmine_lab_flow/molecule_service'
require_relative 'lib/redmine_lab_flow/sequence_service'
require_relative 'lib/redmine_lab_flow/snapshot_service'

# Custom field formats
require_relative 'lib/redmine_lab_flow/molecule_format'
require_relative 'lib/redmine_lab_flow/sequence_format'

Redmine::Plugin.register :redmine_lab_flow do
  name 'Redmine LabFlow'
  author 'Jose'
  description 'ISA-compliant laboratory management for Redmine with ELN integration, data intelligence, and scientific visualizers'
  version '0.5.0'
  requires_redmine version_or_higher: '6.0.0'

  # Plugin settings (configurable units + Phase 5/6 settings)
  settings default: {
    'units' => "units\nmg\nml\ng\nL\nmol\nmmol\nµg\nµL\nµmol\nng\npg\nmM\nµM",
    'starvation_threshold_hours' => '48',
    'enable_doi_minting' => '0',
    'doi_test_mode' => '1',
    'doi_prefix' => '',
    'datacite_repository_id' => '',
    'datacite_password' => ''
  }, partial: 'settings/lab_flow_settings'

  # Project module with permissions
  project_module :laboratory_management do
    permission :view_lab_entities,
               {
                 lab_flow: [:index],
                 wiki_templates: %i[index show],
                 lab_flow_dashboard: [:index, :metrics, :starvation, :bottlenecks],
                 lab_flow_reports: [:history, :download],
                 lab_flow_sequences: [:index, :show, :export],
                 lab_flow_consolidated_view: [:show, :timeline, :compare, :export_history],
                 lab_flow_fair: [:show, :export]
               },
               read: true
    permission :manage_lab_entities,
               {
                 lab_flow: [:configure],
                 lab_flow_settings: [:update],
                 lab_flow_reports: [:generate],
                 lab_flow_webhooks: [:index, :show, :new, :create, :edit, :update, :destroy, :test],
                 lab_flow_external_jobs: [:index, :create, :show, :cancel],
                 lab_flow_sequences: [:new, :create, :edit, :update, :destroy, :restriction_map],
                 lab_flow_sequence_annotations: [:create, :update, :destroy],
                 lab_flow_fair: [:update, :mint_doi]
               }
  end

  # Project menu item (only when module enabled)
  menu :project_menu, :lab_flow,
       { controller: 'lab_flow', action: 'index' },
       param: :project_id,
       caption: :label_lab_flow,
       permission: :view_lab_entities,
       if: Proc.new { |p| p.module_enabled?(:laboratory_management) },
       after: :issues

  # Admin menu for external systems and report templates
  menu :admin_menu, :lab_flow_external_systems,
       { controller: 'lab_flow_external_systems', action: 'index' },
       caption: :label_external_systems,
       html: { class: 'icon icon-network' },
       if: Proc.new { User.current.admin? }

  menu :admin_menu, :lab_flow_report_templates,
       { controller: 'lab_flow_report_templates', action: 'index' },
       caption: :label_report_templates,
       html: { class: 'icon icon-document' },
       if: Proc.new { User.current.admin? }
end

# Register project settings tab and apply patches
Rails.configuration.after_initialize do
  if Redmine::Plugin.installed?(:redmine_lab_flow)
    # Apply Issue patch for finalization and reason-for-change validation
    unless Issue.included_modules.include?(RedmineLabFlow::IssuePatch)
      Issue.include(RedmineLabFlow::IssuePatch)
    end

    # Add associations to Issue model for Phase 5/6
    Issue.class_eval do
      has_many :lab_flow_sequences, class_name: 'LabFlowSequence', dependent: :destroy
      has_many :lab_flow_external_jobs, class_name: 'LabFlowExternalJob', dependent: :destroy
      has_many :lab_flow_property_snapshots, class_name: 'LabFlowPropertySnapshot', dependent: :destroy
      has_one :lab_flow_fair_metadata, class_name: 'LabFlowFairMetadata', dependent: :destroy
    end

    # Auto-setup on first load
    require_relative 'lib/redmine_lab_flow/setup'
    RedmineLabFlow::Setup.install
  end
end

# Register project settings tab via hooks
module RedmineLabFlow
  class ProjectSettingsTab < Redmine::Hook::Listener
    def helper_settings_tabs(context = {})
      return unless context[:project]&.module_enabled?(:laboratory_management)

      context[:tabs] ||= []
      context[:tabs] << {
        name: 'lab_flow',
        partial: 'projects/settings/lab_flow',
        label: :label_lab_flow_settings
      }
    end
  end
end
