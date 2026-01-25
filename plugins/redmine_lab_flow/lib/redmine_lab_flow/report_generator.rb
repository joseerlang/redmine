# frozen_string_literal: true

module RedmineLabFlow
  class ReportGenerator
    def initialize(template, issue, project)
      @template = template
      @issue = issue
      @project = project
      @reports_dir = Rails.root.join('files', 'lab_flow_reports')
    end

    def generate(format)
      ensure_reports_directory

      case format.to_s
      when 'pdf'
        generate_pdf
      when 'xlsx'
        generate_xlsx
      when 'json'
        generate_json
      when 'html'
        generate_html
      else
        raise "Unsupported format: #{format}"
      end
    end

    def full_path(relative_path)
      @reports_dir.join(relative_path)
    end

    private

    def ensure_reports_directory
      FileUtils.mkdir_p(@reports_dir)
    end

    def build_context
      context = {
        'template' => {
          'name' => @template.name,
          'type' => @template.report_type
        },
        'project' => {
          'id' => @project.id,
          'name' => @project.name,
          'identifier' => @project.identifier,
          'description' => @project.description
        },
        'generated_at' => Time.current.iso8601,
        'generated_by' => User.current.name
      }

      if @issue
        context['issue'] = {
          'id' => @issue.id,
          'subject' => @issue.subject,
          'description' => @issue.description,
          'created_on' => @issue.created_on.iso8601,
          'updated_on' => @issue.updated_on.iso8601,
          'due_date' => @issue.due_date&.iso8601
        }
        context['author'] = {
          'name' => @issue.author.name,
          'login' => @issue.author.login,
          'mail' => @issue.author.mail
        }
        context['status'] = { 'name' => @issue.status.name }
        context['tracker'] = { 'name' => @issue.tracker.name }
        context['custom_fields'] = build_custom_fields_context
        context['eln_content'] = build_eln_content if @template.include_eln_narrative
        context['signatures'] = build_signatures_context if @template.include_signatures
      end

      context
    end

    def build_custom_fields_context
      return {} unless @issue

      @issue.custom_field_values.each_with_object({}) do |cfv, hash|
        next if @template.fields_to_include.any? && !@template.fields_to_include.include?(cfv.custom_field.name)

        hash[cfv.custom_field.name] = cfv.value
      end
    end

    def build_eln_content
      return nil unless @issue

      wiki_page = @issue.project.wiki&.pages&.find_by(title: "Issue_#{@issue.id}")
      wiki_page&.content&.text
    end

    def build_signatures_context
      return [] unless @issue && @issue.respond_to?(:lab_flow_electronic_signatures)

      @issue.lab_flow_electronic_signatures.map do |sig|
        {
          'signer' => sig.user.name,
          'role' => sig.role,
          'meaning' => sig.meaning,
          'signed_at' => sig.signed_at.iso8601
        }
      end
    end

    def generate_pdf
      context = build_context
      rendered_content = @template.render(context)

      filename = "report_#{@issue&.id || 'project'}_#{Time.current.to_i}.pdf"
      filepath = @reports_dir.join(filename)

      PdfGenerator.new(rendered_content, context).generate(filepath)

      filename
    end

    def generate_xlsx
      context = build_context

      filename = "report_#{@issue&.id || 'project'}_#{Time.current.to_i}.xlsx"
      filepath = @reports_dir.join(filename)

      ExcelGenerator.new(context, @template).generate(filepath)

      filename
    end

    def generate_json
      context = build_context

      filename = "report_#{@issue&.id || 'project'}_#{Time.current.to_i}.json"
      filepath = @reports_dir.join(filename)

      File.write(filepath, JSON.pretty_generate(context))

      filename
    end

    def generate_html
      context = build_context
      rendered_content = @template.render(context)

      filename = "report_#{@issue&.id || 'project'}_#{Time.current.to_i}.html"
      filepath = @reports_dir.join(filename)

      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>#{CGI.escapeHTML(@template.name)}</title>
          <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
            h1, h2, h3 { color: #333; }
            table { border-collapse: collapse; width: 100%; margin: 20px 0; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f5f5f5; }
            .metadata { color: #666; font-size: 0.9em; margin-bottom: 20px; }
          </style>
        </head>
        <body>
          <div class="metadata">
            Generated: #{context['generated_at']} by #{context['generated_by']}
          </div>
          #{rendered_content}
        </body>
        </html>
      HTML

      File.write(filepath, html)

      filename
    end
  end

  class PdfGenerator
    def initialize(content, context)
      @content = content
      @context = context
    end

    def generate(filepath)
      unless defined?(Prawn)
        File.write(filepath.to_s.sub('.pdf', '.txt'), @content)
        return
      end

      Prawn::Document.generate(filepath) do |pdf|
        pdf.text @context.dig('template', 'name') || 'Report', size: 20, style: :bold
        pdf.move_down 10

        if @context['issue']
          pdf.text "Issue: ##{@context['issue']['id']} - #{@context['issue']['subject']}", size: 14
          pdf.move_down 5
          pdf.text "Status: #{@context.dig('status', 'name')}", size: 10
          pdf.text "Tracker: #{@context.dig('tracker', 'name')}", size: 10
          pdf.move_down 10
        end

        pdf.text @content

        if @context['custom_fields']&.any?
          pdf.move_down 20
          pdf.text 'Custom Fields', size: 14, style: :bold
          pdf.move_down 10

          table_data = [['Field', 'Value']]
          @context['custom_fields'].each do |name, value|
            table_data << [name, value.to_s]
          end

          pdf.table(table_data, header: true, width: pdf.bounds.width) do |t|
            t.row(0).font_style = :bold
            t.row(0).background_color = 'EEEEEE'
          end
        end

        if @context['signatures']&.any?
          pdf.move_down 20
          pdf.text 'Electronic Signatures', size: 14, style: :bold
          pdf.move_down 10

          @context['signatures'].each do |sig|
            pdf.text "#{sig['signer']} (#{sig['role']}): #{sig['meaning']} - #{sig['signed_at']}", size: 10
          end
        end

        pdf.move_down 30
        pdf.text "Generated: #{@context['generated_at']} by #{@context['generated_by']}", size: 8, color: '666666'
      end
    end
  end

  class ExcelGenerator
    def initialize(context, template)
      @context = context
      @template = template
    end

    def generate(filepath)
      unless defined?(Axlsx)
        generate_csv_fallback(filepath)
        return
      end

      package = Axlsx::Package.new
      workbook = package.workbook

      workbook.add_worksheet(name: 'Summary') do |sheet|
        sheet.add_row ['Report', @context.dig('template', 'name')]
        sheet.add_row ['Generated', @context['generated_at']]
        sheet.add_row ['Generated By', @context['generated_by']]

        if @context['issue']
          sheet.add_row []
          sheet.add_row ['Issue ID', @context['issue']['id']]
          sheet.add_row ['Subject', @context['issue']['subject']]
          sheet.add_row ['Status', @context.dig('status', 'name')]
          sheet.add_row ['Tracker', @context.dig('tracker', 'name')]
          sheet.add_row ['Created', @context['issue']['created_on']]
          sheet.add_row ['Updated', @context['issue']['updated_on']]
        end
      end

      if @context['custom_fields']&.any?
        workbook.add_worksheet(name: 'Custom Fields') do |sheet|
          sheet.add_row ['Field', 'Value']
          @context['custom_fields'].each do |name, value|
            sheet.add_row [name, value.to_s]
          end
        end
      end

      if @context['signatures']&.any?
        workbook.add_worksheet(name: 'Signatures') do |sheet|
          sheet.add_row ['Signer', 'Role', 'Meaning', 'Signed At']
          @context['signatures'].each do |sig|
            sheet.add_row [sig['signer'], sig['role'], sig['meaning'], sig['signed_at']]
          end
        end
      end

      package.serialize(filepath)
    end

    private

    def generate_csv_fallback(filepath)
      require 'csv'

      csv_path = filepath.to_s.sub('.xlsx', '.csv')

      CSV.open(csv_path, 'w') do |csv|
        csv << ['Field', 'Value']
        csv << ['Report', @context.dig('template', 'name')]
        csv << ['Generated', @context['generated_at']]

        if @context['issue']
          csv << ['Issue ID', @context['issue']['id']]
          csv << ['Subject', @context['issue']['subject']]
          csv << ['Status', @context.dig('status', 'name')]
        end

        @context['custom_fields']&.each do |name, value|
          csv << [name, value.to_s]
        end
      end
    end
  end
end
