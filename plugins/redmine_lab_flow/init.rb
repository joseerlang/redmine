# frozen_string_literal: true

# Load helpers and patches
require_relative 'lib/redmine_lab_flow/helpers'
require_relative 'lib/redmine_lab_flow/hooks'
require_relative 'lib/redmine_lab_flow/issue_patch'
require_relative 'lib/redmine_lab_flow/wiki_reference_format'

Redmine::Plugin.register :redmine_lab_flow do
  name 'Redmine LabFlow'
  author 'Jose'
  description 'ISA-compliant laboratory management for Redmine with ELN integration'
  version '0.3.0'
  requires_redmine version_or_higher: '6.0.0'

  # Plugin settings (configurable units)
  settings default: {
    'units' => "units\nmg\nml\ng\nL\nmol\nmmol\nµg\nµL\nµmol\nng\npg\nmM\nµM"
  }, partial: 'settings/lab_flow_settings'

  # Project module with permissions
  project_module :laboratory_management do
    permission :view_lab_entities,
               { lab_flow: [:index], wiki_templates: %i[index show] },
               read: true
    permission :manage_lab_entities,
               { lab_flow: [:configure], lab_flow_settings: [:update] }
  end

  # Project menu item (only when module enabled)
  menu :project_menu, :lab_flow,
       { controller: 'lab_flow', action: 'index' },
       param: :project_id,
       caption: :label_lab_flow,
       permission: :view_lab_entities,
       if: Proc.new { |p| p.module_enabled?(:laboratory_management) },
       after: :issues

  # Admin menu for procedure templates
  menu :admin_menu, :procedure_templates,
       { controller: 'procedure_templates', action: 'index' },
       caption: :label_procedure_templates,
       html: { class: 'icon icon-list' },
       after: :custom_fields

  # Admin menu for lab reagents
  menu :admin_menu, :lab_reagents,
       { controller: 'lab_reagents', action: 'index' },
       caption: :label_lab_reagents,
       html: { class: 'icon icon-package' },
       after: :procedure_templates

  # Admin menu for lab equipment
  menu :admin_menu, :lab_equipment,
       { controller: 'lab_equipment', action: 'index' },
       caption: :label_lab_equipment,
       html: { class: 'icon icon-server-authentication' },
       after: :lab_reagents
end

# Register project settings tab and apply patches
Rails.configuration.after_initialize do
  if Redmine::Plugin.installed?(:redmine_lab_flow)
    # Apply Issue patch for finalization and reason-for-change validation
    unless Issue.included_modules.include?(RedmineLabFlow::IssuePatch)
      Issue.include(RedmineLabFlow::IssuePatch)
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
