# frozen_string_literal: true

module RedmineLabFlow
  class PdfGenerator
    attr_reader :issue, :template, :options

    def initialize(issue, template, options = {})
      @issue = issue
      @template = template
      @options = options
    end

    def generate
      return generate_with_prawn if prawn_available?

      generate_html_fallback
    end

    private

    def prawn_available?
      defined?(Prawn)
    rescue
      false
    end

    def generate_with_prawn
      require 'prawn'
      require 'prawn/table' if defined?(Prawn::Table)

      pdf = Prawn::Document.new(page_size: 'A4', margin: 50)

      # Header
      pdf.text template.name, size: 20, style: :bold
      pdf.text "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M')}", size: 10, color: '666666'
      pdf.move_down 20

      # Issue details
      pdf.text "Issue: ##{issue.id} - #{issue.subject}", size: 14, style: :bold
      pdf.move_down 10

      # Basic info table
      data = [
        ['Status', issue.status.name],
        ['Tracker', issue.tracker.name],
        ['Priority', issue.priority.name],
        ['Assigned to', issue.assigned_to&.name || '-'],
        ['Created', issue.created_on.strftime('%Y-%m-%d')],
        ['Updated', issue.updated_on.strftime('%Y-%m-%d')]
      ]

      pdf.table(data, width: 400) do |t|
        t.cells.padding = 5
        t.column(0).font_style = :bold
        t.column(0).width = 120
      end
      pdf.move_down 15

      # Custom fields
      if issue.visible_custom_field_values.any?
        pdf.text 'Custom Fields', size: 12, style: :bold
        pdf.move_down 5

        cf_data = issue.visible_custom_field_values.map do |cv|
          [cv.custom_field.name, cv.value.to_s]
        end

        pdf.table(cf_data, width: 400) do |t|
          t.cells.padding = 5
          t.column(0).font_style = :bold
          t.column(0).width = 150
        end
        pdf.move_down 15
      end

      # Description / ELN narrative
      if template.include_eln_narrative && issue.description.present?
        pdf.text 'Description / ELN Narrative', size: 12, style: :bold
        pdf.move_down 5
        pdf.text issue.description, size: 10
        pdf.move_down 15
      end

      # Signatures if included
      if template.include_signatures && issue.respond_to?(:lab_flow_electronic_signatures)
        signatures = issue.lab_flow_electronic_signatures
        if signatures.any?
          pdf.text 'Electronic Signatures', size: 12, style: :bold
          pdf.move_down 5

          sig_data = signatures.map do |sig|
            [sig.user.name, sig.signature_type, sig.signed_at.strftime('%Y-%m-%d %H:%M')]
          end

          pdf.table([['Signer', 'Type', 'Date']] + sig_data, width: 400) do |t|
            t.cells.padding = 5
            t.row(0).font_style = :bold
            t.row(0).background_color = 'EEEEEE'
          end
        end
      end

      # Footer
      pdf.repeat(:all) do
        pdf.bounding_box([0, 30], width: pdf.bounds.width, height: 30) do
          pdf.text "Page #{pdf.page_number}", size: 9, align: :center, color: '999999'
        end
      end

      pdf.render
    end

    def generate_html_fallback
      # Fallback when Prawn is not available - generates HTML that can be printed
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>#{ERB::Util.html_escape(template.name)}</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            h1 { color: #333; border-bottom: 2px solid #333; padding-bottom: 10px; }
            h2 { color: #666; margin-top: 20px; }
            table { border-collapse: collapse; width: 100%; margin: 10px 0; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f5f5f5; font-weight: bold; }
            .meta { color: #999; font-size: 12px; }
            .description { background: #f9f9f9; padding: 15px; border-radius: 4px; white-space: pre-wrap; }
            @media print {
              body { margin: 20px; }
              .no-print { display: none; }
            }
          </style>
        </head>
        <body>
          <h1>#{ERB::Util.html_escape(template.name)}</h1>
          <p class="meta">Generated: #{Time.current.strftime('%Y-%m-%d %H:%M')}</p>

          <h2>Issue ##{issue.id} - #{ERB::Util.html_escape(issue.subject)}</h2>

          <table>
            <tr><th>Status</th><td>#{ERB::Util.html_escape(issue.status.name)}</td></tr>
            <tr><th>Tracker</th><td>#{ERB::Util.html_escape(issue.tracker.name)}</td></tr>
            <tr><th>Priority</th><td>#{ERB::Util.html_escape(issue.priority.name)}</td></tr>
            <tr><th>Assigned to</th><td>#{ERB::Util.html_escape(issue.assigned_to&.name || '-')}</td></tr>
            <tr><th>Created</th><td>#{issue.created_on.strftime('%Y-%m-%d')}</td></tr>
            <tr><th>Updated</th><td>#{issue.updated_on.strftime('%Y-%m-%d')}</td></tr>
          </table>

          #{render_custom_fields_html}
          #{render_description_html if template.include_eln_narrative}
          #{render_signatures_html if template.include_signatures}
        </body>
        </html>
      HTML

      html
    end

    def render_custom_fields_html
      return '' unless issue.visible_custom_field_values.any?

      rows = issue.visible_custom_field_values.map do |cv|
        "<tr><th>#{ERB::Util.html_escape(cv.custom_field.name)}</th><td>#{ERB::Util.html_escape(cv.value.to_s)}</td></tr>"
      end.join("\n")

      <<~HTML
        <h2>Custom Fields</h2>
        <table>#{rows}</table>
      HTML
    end

    def render_description_html
      return '' unless issue.description.present?

      <<~HTML
        <h2>Description / ELN Narrative</h2>
        <div class="description">#{ERB::Util.html_escape(issue.description)}</div>
      HTML
    end

    def render_signatures_html
      return '' unless issue.respond_to?(:lab_flow_electronic_signatures)

      signatures = issue.lab_flow_electronic_signatures
      return '' unless signatures.any?

      rows = signatures.map do |sig|
        "<tr><td>#{ERB::Util.html_escape(sig.user.name)}</td><td>#{ERB::Util.html_escape(sig.signature_type)}</td><td>#{sig.signed_at.strftime('%Y-%m-%d %H:%M')}</td></tr>"
      end.join("\n")

      <<~HTML
        <h2>Electronic Signatures</h2>
        <table>
          <tr><th>Signer</th><th>Type</th><th>Date</th></tr>
          #{rows}
        </table>
      HTML
    end
  end
end
