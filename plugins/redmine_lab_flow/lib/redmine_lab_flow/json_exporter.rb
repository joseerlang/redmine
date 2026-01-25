# frozen_string_literal: true

module RedmineLabFlow
  class JsonExporter
    attr_reader :issue, :template, :options

    def initialize(issue, template, options = {})
      @issue = issue
      @template = template
      @options = options
    end

    def generate
      data = build_export_data
      JSON.pretty_generate(data)
    end

    def build_export_data
      data = {
        meta: {
          report_name: template.name,
          report_type: template.report_type,
          generated_at: Time.current.iso8601,
          generator: 'Redmine LabFlow',
          version: '0.5.0'
        },
        issue: build_issue_data
      }

      data[:custom_fields] = build_custom_fields_data if issue.visible_custom_field_values.any?
      data[:description] = issue.description if template.include_eln_narrative && issue.description.present?
      data[:signatures] = build_signatures_data if template.include_signatures
      data[:audit_trail] = build_audit_trail_data if options[:include_audit_trail]
      data[:sequences] = build_sequences_data if issue.respond_to?(:lab_flow_sequences)
      data[:fair_metadata] = build_fair_metadata if issue.respond_to?(:lab_flow_fair_metadata)
      data[:external_jobs] = build_external_jobs_data if issue.respond_to?(:lab_flow_external_jobs)

      data
    end

    private

    def build_issue_data
      {
        id: issue.id,
        subject: issue.subject,
        status: {
          id: issue.status.id,
          name: issue.status.name
        },
        tracker: {
          id: issue.tracker.id,
          name: issue.tracker.name
        },
        priority: {
          id: issue.priority.id,
          name: issue.priority.name
        },
        project: {
          id: issue.project.id,
          identifier: issue.project.identifier,
          name: issue.project.name
        },
        author: {
          id: issue.author.id,
          name: issue.author.name,
          login: issue.author.login
        },
        assigned_to: issue.assigned_to ? {
          id: issue.assigned_to.id,
          name: issue.assigned_to.name,
          login: issue.assigned_to.login
        } : nil,
        created_on: issue.created_on.iso8601,
        updated_on: issue.updated_on.iso8601,
        closed_on: issue.closed_on&.iso8601,
        start_date: issue.start_date&.to_s,
        due_date: issue.due_date&.to_s,
        done_ratio: issue.done_ratio,
        estimated_hours: issue.estimated_hours
      }
    end

    def build_custom_fields_data
      issue.visible_custom_field_values.map do |cv|
        {
          id: cv.custom_field.id,
          name: cv.custom_field.name,
          field_format: cv.custom_field.field_format,
          value: cv.value,
          multiple: cv.custom_field.multiple?
        }
      end
    end

    def build_signatures_data
      return [] unless issue.respond_to?(:lab_flow_electronic_signatures)

      issue.lab_flow_electronic_signatures.map do |sig|
        {
          id: sig.id,
          user: {
            id: sig.user.id,
            name: sig.user.name
          },
          signature_type: sig.signature_type,
          signed_at: sig.signed_at.iso8601,
          reason: sig.reason,
          verified: sig.verified?
        }
      end
    end

    def build_audit_trail_data
      issue.journals.map do |journal|
        {
          id: journal.id,
          user: {
            id: journal.user.id,
            name: journal.user.name
          },
          created_on: journal.created_on.iso8601,
          notes: journal.notes,
          details: journal.details.map do |detail|
            {
              property: detail.property,
              prop_key: detail.prop_key,
              old_value: detail.old_value,
              value: detail.value
            }
          end
        }
      end
    end

    def build_sequences_data
      return [] unless issue.respond_to?(:lab_flow_sequences)

      issue.lab_flow_sequences.map do |seq|
        {
          id: seq.id,
          name: seq.name,
          sequence_type: seq.sequence_type,
          length: seq.length,
          circular: seq.circular?,
          gc_content: seq.gc_content,
          annotations_count: seq.annotations.count
        }
      end
    end

    def build_fair_metadata
      metadata = issue.lab_flow_fair_metadata
      return nil unless metadata

      {
        doi: metadata.doi,
        license: metadata.license,
        access_level: metadata.access_level,
        keywords: metadata.keywords,
        fair_score: metadata.fair_score,
        created_at: metadata.created_at.iso8601,
        updated_at: metadata.updated_at.iso8601
      }
    end

    def build_external_jobs_data
      return [] unless issue.respond_to?(:lab_flow_external_jobs)

      issue.lab_flow_external_jobs.map do |job|
        {
          id: job.id,
          external_system: job.external_system.name,
          job_type: job.job_type,
          status: job.status,
          external_job_id: job.external_job_id,
          submitted_at: job.submitted_at&.iso8601,
          finished_at: job.finished_at&.iso8601
        }
      end
    end
  end
end
