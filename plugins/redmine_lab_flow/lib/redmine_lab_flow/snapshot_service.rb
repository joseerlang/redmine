# frozen_string_literal: true

module RedmineLabFlow
  class SnapshotService
    def initialize(issue)
      @issue = issue
    end

    # Create a snapshot of current issue state
    def create_snapshot(trigger: 'manual', user: nil, journal: nil)
      LabFlowPropertySnapshot.create_from_issue(
        @issue,
        trigger: trigger,
        user: user || User.current,
        journal: journal
      )
    end

    # Get all snapshots for the issue
    def snapshots
      LabFlowPropertySnapshot.for_issue(@issue)
    end

    # Compare two snapshots
    def diff_snapshots(snapshot1, snapshot2)
      return {} unless snapshot1 && snapshot2

      snapshot2.diff(snapshot1)
    end

    # Build a timeline of all changes
    def build_timeline
      timeline_entries = []

      # Add snapshots
      snapshots.each do |snapshot|
        timeline_entries << {
          type: 'snapshot',
          timestamp: snapshot.created_at,
          data: snapshot,
          summary: snapshot.change_summary
        }
      end

      # Add journal entries
      @issue.journals.includes(:details, :user).each do |journal|
        next if journal.details.empty? && journal.notes.blank?

        timeline_entries << {
          type: 'journal',
          timestamp: journal.created_on,
          data: journal,
          summary: build_journal_summary(journal)
        }
      end

      # Add attachments
      @issue.attachments.each do |attachment|
        timeline_entries << {
          type: 'attachment',
          timestamp: attachment.created_on,
          data: attachment,
          summary: "Attached: #{attachment.filename}"
        }
      end

      timeline_entries.sort_by { |e| e[:timestamp] }
    end

    # Export timeline as structured data
    def export_timeline(format: 'json')
      timeline = build_timeline

      case format.to_s
      when 'json'
        timeline.map do |entry|
          {
            type: entry[:type],
            timestamp: entry[:timestamp].iso8601,
            summary: entry[:summary],
            data: serialize_entry_data(entry)
          }
        end
      when 'csv'
        generate_csv(timeline)
      else
        timeline
      end
    end

    private

    def build_journal_summary(journal)
      changes = []

      journal.details.each do |detail|
        case detail.property
        when 'attr'
          changes << describe_attribute_change(detail)
        when 'cf'
          cf = CustomField.find_by(id: detail.prop_key)
          changes << "#{cf&.name || 'Custom field'}: #{detail.old_value} -> #{detail.value}"
        when 'attachment'
          changes << "Attachment: #{detail.value}"
        end
      end

      changes << "Note added" if journal.notes.present?

      changes.join('; ')
    end

    def describe_attribute_change(detail)
      case detail.prop_key
      when 'status_id'
        old_status = IssueStatus.find_by(id: detail.old_value)
        new_status = IssueStatus.find_by(id: detail.value)
        "Status: #{old_status&.name} -> #{new_status&.name}"
      when 'assigned_to_id'
        old_user = User.find_by(id: detail.old_value)
        new_user = User.find_by(id: detail.value)
        "Assigned: #{old_user&.name || 'none'} -> #{new_user&.name || 'none'}"
      when 'priority_id'
        old_priority = IssuePriority.find_by(id: detail.old_value)
        new_priority = IssuePriority.find_by(id: detail.value)
        "Priority: #{old_priority&.name} -> #{new_priority&.name}"
      else
        "#{detail.prop_key}: #{detail.old_value} -> #{detail.value}"
      end
    end

    def serialize_entry_data(entry)
      case entry[:type]
      when 'snapshot'
        {
          id: entry[:data].id,
          trigger: entry[:data].trigger_event,
          snapshot_data: entry[:data].snapshot_data
        }
      when 'journal'
        {
          id: entry[:data].id,
          user: entry[:data].user&.name,
          notes: entry[:data].notes,
          details: entry[:data].details.map do |d|
            {
              property: d.property,
              key: d.prop_key,
              old_value: d.old_value,
              new_value: d.value
            }
          end
        }
      when 'attachment'
        {
          id: entry[:data].id,
          filename: entry[:data].filename,
          filesize: entry[:data].filesize,
          content_type: entry[:data].content_type
        }
      else
        {}
      end
    end

    def generate_csv(timeline)
      require 'csv'

      CSV.generate do |csv|
        csv << ['Timestamp', 'Type', 'Summary', 'User']

        timeline.each do |entry|
          user = case entry[:type]
                 when 'journal' then entry[:data].user&.name
                 when 'attachment' then entry[:data].author&.name
                 when 'snapshot' then entry[:data].created_by&.name
                 else nil
                 end

          csv << [
            entry[:timestamp].iso8601,
            entry[:type],
            entry[:summary],
            user
          ]
        end
      end
    end
  end
end
