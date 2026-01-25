# frozen_string_literal: true

module RedmineLabFlow
  class ExcelGenerator
    attr_reader :issue, :template, :options

    def initialize(issue, template, options = {})
      @issue = issue
      @template = template
      @options = options
    end

    def generate
      return generate_with_caxlsx if caxlsx_available?

      generate_csv_fallback
    end

    def content_type
      caxlsx_available? ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'text/csv'
    end

    def file_extension
      caxlsx_available? ? 'xlsx' : 'csv'
    end

    private

    def caxlsx_available?
      defined?(Axlsx)
    rescue
      false
    end

    def generate_with_caxlsx
      require 'caxlsx'

      package = Axlsx::Package.new
      workbook = package.workbook

      # Styles
      header_style = workbook.styles.add_style(
        bg_color: '4472C4',
        fg_color: 'FFFFFF',
        b: true,
        alignment: { horizontal: :center }
      )

      bold_style = workbook.styles.add_style(b: true)
      date_style = workbook.styles.add_style(format_code: 'yyyy-mm-dd hh:mm')

      # Main sheet - Issue Details
      workbook.add_worksheet(name: 'Issue Details') do |sheet|
        sheet.add_row ['Report: ' + template.name], style: bold_style
        sheet.add_row ['Generated: ' + Time.current.strftime('%Y-%m-%d %H:%M')]
        sheet.add_row []

        sheet.add_row ['Issue Information'], style: header_style
        sheet.add_row ['ID', issue.id]
        sheet.add_row ['Subject', issue.subject]
        sheet.add_row ['Status', issue.status.name]
        sheet.add_row ['Tracker', issue.tracker.name]
        sheet.add_row ['Priority', issue.priority.name]
        sheet.add_row ['Assigned to', issue.assigned_to&.name || '-']
        sheet.add_row ['Author', issue.author.name]
        sheet.add_row ['Created', issue.created_on]
        sheet.add_row ['Updated', issue.updated_on]
        sheet.add_row []

        # Custom fields
        if issue.visible_custom_field_values.any?
          sheet.add_row ['Custom Fields'], style: header_style
          issue.visible_custom_field_values.each do |cv|
            sheet.add_row [cv.custom_field.name, cv.value.to_s]
          end
          sheet.add_row []
        end

        # Description
        if template.include_eln_narrative && issue.description.present?
          sheet.add_row ['Description / ELN Narrative'], style: header_style
          sheet.add_row [issue.description]
        end

        # Auto-fit columns
        sheet.column_widths 30, 50
      end

      # Signatures sheet
      if template.include_signatures && issue.respond_to?(:lab_flow_electronic_signatures)
        signatures = issue.lab_flow_electronic_signatures
        if signatures.any?
          workbook.add_worksheet(name: 'Signatures') do |sheet|
            sheet.add_row ['Signer', 'Type', 'Date', 'Reason'], style: header_style

            signatures.each do |sig|
              sheet.add_row [
                sig.user.name,
                sig.signature_type,
                sig.signed_at,
                sig.reason
              ]
            end

            sheet.column_widths 25, 15, 20, 40
          end
        end
      end

      # Audit trail sheet
      if issue.journals.any?
        workbook.add_worksheet(name: 'Audit Trail') do |sheet|
          sheet.add_row ['Date', 'User', 'Changes', 'Notes'], style: header_style

          issue.journals.each do |journal|
            changes = journal.details.map do |detail|
              "#{detail.prop_key}: #{detail.old_value} -> #{detail.value}"
            end.join('; ')

            sheet.add_row [
              journal.created_on,
              journal.user.name,
              changes,
              journal.notes.to_s.truncate(100)
            ]
          end

          sheet.column_widths 20, 20, 50, 50
        end
      end

      package.to_stream.read
    end

    def generate_csv_fallback
      require 'csv'

      CSV.generate do |csv|
        csv << ['Report', template.name]
        csv << ['Generated', Time.current.strftime('%Y-%m-%d %H:%M')]
        csv << []

        csv << ['Issue Information']
        csv << ['ID', issue.id]
        csv << ['Subject', issue.subject]
        csv << ['Status', issue.status.name]
        csv << ['Tracker', issue.tracker.name]
        csv << ['Priority', issue.priority.name]
        csv << ['Assigned to', issue.assigned_to&.name || '-']
        csv << ['Author', issue.author.name]
        csv << ['Created', issue.created_on.strftime('%Y-%m-%d %H:%M')]
        csv << ['Updated', issue.updated_on.strftime('%Y-%m-%d %H:%M')]
        csv << []

        # Custom fields
        if issue.visible_custom_field_values.any?
          csv << ['Custom Fields']
          issue.visible_custom_field_values.each do |cv|
            csv << [cv.custom_field.name, cv.value.to_s]
          end
          csv << []
        end

        # Description
        if template.include_eln_narrative && issue.description.present?
          csv << ['Description']
          csv << [issue.description]
          csv << []
        end

        # Signatures
        if template.include_signatures && issue.respond_to?(:lab_flow_electronic_signatures)
          signatures = issue.lab_flow_electronic_signatures
          if signatures.any?
            csv << ['Signatures']
            csv << ['Signer', 'Type', 'Date', 'Reason']
            signatures.each do |sig|
              csv << [sig.user.name, sig.signature_type, sig.signed_at.strftime('%Y-%m-%d %H:%M'), sig.reason]
            end
          end
        end
      end
    end
  end
end
