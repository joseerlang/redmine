# frozen_string_literal: true

namespace :lab_flow do
  desc 'Seed example procedure templates for LabFlow plugin'
  task seed_templates: :environment do
    require_relative '../redmine_lab_flow/seed_examples'

    puts 'Seeding LabFlow procedure templates...'
    RedmineLabFlow::SeedExamples.seed_templates
    puts "Done! Created #{LabFlowProcedureTemplate.count} templates."
  end

  desc 'Seed example Wiki SOPs for a project (PROJECT=identifier)'
  task seed_wiki_sops: :environment do
    require_relative '../redmine_lab_flow/seed_examples'

    project_id = ENV['PROJECT']
    if project_id.blank?
      puts 'ERROR: Please specify PROJECT=identifier'
      puts 'Example: rake lab_flow:seed_wiki_sops PROJECT=my-lab-project'
      exit 1
    end

    project = Project.find_by(identifier: project_id)
    if project.nil?
      puts "ERROR: Project '#{project_id}' not found"
      exit 1
    end

    unless project.wiki
      puts "Creating wiki for project '#{project.name}'..."
      Wiki.create!(project: project, start_page: 'Wiki')
    end

    puts "Seeding Wiki SOPs for project '#{project.name}'..."
    RedmineLabFlow::SeedExamples.seed_example_project_with_wiki(project)
    puts 'Done!'
  end

  desc 'Create a complete example project with all LabFlow features'
  task create_example_project: :environment do
    require_relative '../redmine_lab_flow/seed_examples'
    require_relative '../redmine_lab_flow/setup'

    puts '=' * 60
    puts 'Creating LabFlow Example Project'
    puts '=' * 60

    # Ensure setup is complete
    puts "\n[1/6] Running LabFlow setup..."
    RedmineLabFlow::Setup.install
    puts '      Trackers and custom fields ready.'

    # Seed templates
    puts "\n[2/6] Seeding procedure templates..."
    RedmineLabFlow::SeedExamples.seed_templates
    puts "      #{LabFlowProcedureTemplate.count} templates available."

    # Create example project
    puts "\n[3/6] Creating example project..."
    project = Project.find_by(identifier: 'labflow-demo')

    if project
      puts '      Project already exists, skipping creation.'
    else
      project = Project.create!(
        name: 'LabFlow Demo Project',
        identifier: 'labflow-demo',
        description: 'Demonstration project showcasing LabFlow ELN features',
        is_public: false
      )
      puts "      Created project: #{project.name}"
    end

    # Enable modules
    puts "\n[4/6] Enabling required modules..."
    %i[laboratory_management wiki issue_tracking].each do |mod|
      project.enable_module!(mod) unless project.module_enabled?(mod)
    end

    # Associate trackers
    daily_log = Tracker.find_by(name: I18n.t(:label_daily_log))
    sample = Tracker.find_by(name: I18n.t(:label_sample))
    assay = Tracker.find_by(name: I18n.t(:label_assay))
    [daily_log, sample, assay].compact.each do |tracker|
      project.trackers << tracker unless project.trackers.include?(tracker)
    end
    puts '      Modules and trackers configured.'

    # Create wiki and SOPs
    puts "\n[5/6] Creating Wiki SOPs..."
    unless project.wiki
      Wiki.create!(project: project, start_page: 'Wiki')
    end
    RedmineLabFlow::SeedExamples.seed_example_project_with_wiki(project)
    puts "      #{project.wiki.pages.count} Wiki pages created."

    # Create example issues
    puts "\n[6/6] Creating example lab entries..."
    create_example_issues(project, daily_log, sample, assay)

    puts "\n" + '=' * 60
    puts 'LabFlow Demo Project Ready!'
    puts '=' * 60
    puts "\nAccess your demo project at:"
    puts "  /projects/labflow-demo"
    puts "\nAdmin menu - Procedure Templates:"
    puts "  /procedure_templates"
    puts "\nCredentials: admin / admin"
  end

  def create_example_issues(project, daily_log, sample, assay)
    return unless daily_log && sample && assay

    user = User.find_by(login: 'admin') || User.first
    default_status = IssueStatus.sorted.first
    default_priority = IssuePriority.default || IssuePriority.first

    # Sample entries
    if project.issues.where(tracker: sample).count.zero?
      [
        { subject: 'Soil Sample A-001', internal_id: 'SOIL-2024-001', type: 'Environmental' },
        { subject: 'Water Sample W-001', internal_id: 'WATER-2024-001', type: 'Environmental' },
        { subject: 'Reference Standard RS-01', internal_id: 'STD-2024-001', type: 'Standard' }
      ].each do |data|
        issue = Issue.new(
          project: project,
          tracker: sample,
          status: default_status,
          priority: default_priority,
          subject: data[:subject],
          author: user,
          description: "Sample for analysis. Type: #{data[:type]}"
        )
        set_custom_field_value(issue, 'Internal ID', data[:internal_id])
        set_custom_field_value(issue, 'Sample Type', data[:type])
        issue.save!
      end
      puts '      Created 3 sample entries.'
    end

    # Daily Log entries
    if project.issues.where(tracker: daily_log).count.zero?
      [
        {
          subject: 'Initial Lab Setup and Calibration',
          ref: 'EXP-2024-001',
          desc: "## Objective\nPerform initial setup and calibration of analytical instruments.\n\n## Activities\n- Calibrated pH meter\n- Verified balance accuracy\n- Prepared reagent solutions"
        },
        {
          subject: 'Sample Preparation Batch 001',
          ref: 'EXP-2024-002',
          desc: "## Objective\nPrepare soil samples for metals analysis.\n\n## Samples Processed\n- SOIL-2024-001\n\n## Protocol Reference\nFollowed Sample-Handling-SOP v1.0"
        },
        {
          subject: 'HPLC Analysis Run 001',
          ref: 'EXP-2024-003',
          desc: "## Objective\nAnalyze prepared extracts by HPLC.\n\n## Method\nAM-HPLC-001 v2.1\n\n## Results\nSystem suitability passed. All QC within acceptance criteria."
        }
      ].each do |data|
        issue = Issue.new(
          project: project,
          tracker: daily_log,
          status: default_status,
          priority: default_priority,
          subject: data[:subject],
          author: user,
          description: data[:desc]
        )
        set_custom_field_value(issue, 'Experiment Reference', data[:ref])
        issue.save!
      end
      puts '      Created 3 daily log entries.'
    end

    # Assay entries
    if project.issues.where(tracker: assay).count.zero?
      [
        { subject: 'pH Analysis - SOIL-2024-001', value: 7.2, unit: 'units', method: 'EPA 9045D' },
        { subject: 'Lead Analysis - SOIL-2024-001', value: 15.3, unit: 'mg', method: 'EPA 6010D' },
        { subject: 'TOC Analysis - WATER-2024-001', value: 2.8, unit: 'mg', method: 'SM 5310B' }
      ].each do |data|
        issue = Issue.new(
          project: project,
          tracker: assay,
          status: default_status,
          priority: default_priority,
          subject: data[:subject],
          author: user,
          description: "Analysis performed per #{data[:method]}"
        )
        set_custom_field_value(issue, 'Measured Value', data[:value].to_s)
        set_custom_field_value(issue, 'Unit', data[:unit])
        set_custom_field_value(issue, 'Method', data[:method])
        issue.save!
      end
      puts '      Created 3 assay entries.'
    end
  end

  def set_custom_field_value(issue, field_name, value)
    cf = IssueCustomField.find_by(name: field_name)
    return unless cf

    issue.custom_field_values = { cf.id => value }
  end
end
