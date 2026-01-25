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

  # =============================================================================
  # Phase 5 & 6: Data Intelligence & Scientific Visualizers
  # =============================================================================

  desc 'Calculate daily workflow metrics for all projects'
  task calculate_metrics: :environment do
    puts "Calculating workflow metrics..."

    Project.active.each do |project|
      next unless project.module_enabled?(:lab_flow)

      puts "  Processing project: #{project.name}"
      RedmineLabFlow::MetricsCalculator.calculate_daily_metrics(project)
    end

    puts "Done calculating metrics."
  end

  desc 'Detect starvation (stuck issues) and send notifications'
  task detect_starvation: :environment do
    puts "Detecting starvation..."

    threshold_days = ENV['STARVATION_DAYS']&.to_i || 7

    Project.active.each do |project|
      next unless project.module_enabled?(:lab_flow)

      stuck_issues = RedmineLabFlow::MetricsCalculator.detect_starvation(project, threshold_days)

      if stuck_issues.any?
        puts "  #{project.name}: #{stuck_issues.count} stuck issues"

        # Send notifications if configured
        if Setting.plugin_redmine_lab_flow['notify_on_starvation']
          stuck_issues.each do |issue|
            Mailer.lab_flow_starvation_alert(issue).deliver_later if Mailer.respond_to?(:lab_flow_starvation_alert)
          end
        end
      end
    end

    puts "Done detecting starvation."
  end

  desc 'Refresh external job statuses'
  task refresh_jobs: :environment do
    puts "Refreshing external job statuses..."

    pending_jobs = LabFlowExternalJob.where(status: ['pending', 'running'])

    pending_jobs.find_each do |job|
      puts "  Checking job #{job.id} (#{job.external_system.name})"

      begin
        client = job.external_system.client
        status = client.job_status(job.external_job_id)

        if status[:status] != job.status
          job.update!(
            status: status[:status],
            result_data: status[:result],
            finished_at: status[:finished_at]
          )
          puts "    Updated to: #{status[:status]}"
        end
      rescue => e
        puts "    Error: #{e.message}"
      end
    end

    puts "Done refreshing jobs."
  end

  desc 'Clean up old generated reports (older than 30 days by default)'
  task cleanup_reports: :environment do
    days = ENV['REPORT_RETENTION_DAYS']&.to_i || 30

    puts "Cleaning up reports older than #{days} days..."

    old_reports = LabFlowGeneratedReport.where('created_at < ?', days.days.ago)
    count = old_reports.count

    old_reports.find_each do |report|
      report.file&.purge if report.respond_to?(:file) && report.file.respond_to?(:purge)
      report.destroy
    end

    puts "Deleted #{count} old reports."
  end

  desc 'Sync ontology terms from configured sources'
  task sync_ontologies: :environment do
    puts "Syncing ontology terms..."

    sources = Setting.plugin_redmine_lab_flow['ontology_sources'] || []

    sources.each do |source|
      puts "  Syncing from: #{source['name']}"

      begin
        count = LabFlowOntologyTerm.sync_from_source(source) if LabFlowOntologyTerm.respond_to?(:sync_from_source)
        puts "    Synced #{count || 0} terms"
      rescue => e
        puts "    Error: #{e.message}"
      end
    end

    puts "Done syncing ontologies."
  end

  desc 'Export FAIR metadata for all issues with DOIs'
  task export_fair: :environment do
    output_dir = ENV['FAIR_OUTPUT_DIR'] || Rails.root.join('tmp', 'fair_exports')
    FileUtils.mkdir_p(output_dir)

    puts "Exporting FAIR metadata to #{output_dir}..."

    LabFlowFairMetadata.where.not(doi: nil).find_each do |metadata|
      issue = metadata.issue

      # Export Schema.org JSON-LD
      jsonld = RedmineLabFlow::FairExporter.export_schema_org(issue)
      File.write(File.join(output_dir, "issue_#{issue.id}_schema_org.json"), jsonld.to_json)

      # Export DataCite XML
      datacite = RedmineLabFlow::FairExporter.export_datacite(issue)
      File.write(File.join(output_dir, "issue_#{issue.id}_datacite.xml"), datacite)

      puts "  Exported issue ##{issue.id}"
    end

    puts "Done exporting FAIR metadata."
  end

  desc 'Create property snapshots for all issues'
  task create_snapshots: :environment do
    puts "Creating property snapshots..."

    Issue.open.find_each do |issue|
      next unless issue.project.module_enabled?(:lab_flow)

      RedmineLabFlow::SnapshotService.create_snapshot(issue, User.current)
    end

    puts "Done creating snapshots."
  end

  desc 'Dispatch pending webhooks'
  task dispatch_webhooks: :environment do
    puts "Dispatching pending webhooks..."

    # Find webhooks that need to be retried
    LabFlowWebhook.where(active: true).find_each do |webhook|
      # This would be called by the webhook dispatcher when events occur
      puts "  Webhook #{webhook.id}: #{webhook.name} (#{webhook.event_type})"
    end

    puts "Done."
  end

  # =============================================================================
  # Original tasks
  # =============================================================================

  desc 'Fix workflow status order (Verified should be between QC Pending and Completed)'
  task fix_status_order: :environment do
    require_relative '../redmine_lab_flow/setup'

    puts 'Fixing LabFlow workflow status order...'

    # Get statuses
    qc_pending = IssueStatus.find_by(name: I18n.t(:label_status_qc_pending))
    verified = IssueStatus.find_by(name: I18n.t(:label_status_verified))
    completed = IssueStatus.find_by(name: I18n.t(:label_status_completed))

    unless qc_pending && verified && completed
      puts 'ERROR: Could not find all required statuses.'
      puts "  QC Pending: #{qc_pending&.name || 'NOT FOUND'}"
      puts "  Verified: #{verified&.name || 'NOT FOUND'}"
      puts "  Completed: #{completed&.name || 'NOT FOUND'}"
      exit 1
    end

    puts "Current positions:"
    puts "  QC Pending: #{qc_pending.position}"
    puts "  Verified: #{verified.position}"
    puts "  Completed: #{completed.position}"

    # Verified should be between QC Pending and Completed
    # Set Verified position to QC Pending + 1, then Completed to Verified + 1
    new_verified_position = qc_pending.position + 1
    new_completed_position = new_verified_position + 1

    # Update positions
    verified.update_column(:position, new_verified_position)
    completed.update_column(:position, new_completed_position)

    puts "\nNew positions:"
    puts "  QC Pending: #{qc_pending.reload.position}"
    puts "  Verified: #{verified.reload.position}"
    puts "  Completed: #{completed.reload.position}"

    puts "\nDone! Status order fixed."
  end
end
