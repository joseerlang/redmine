# frozen_string_literal: true

require 'net/http'
require 'json'

module RedmineLabFlow
  class DoiMinter
    DATACITE_API = 'https://api.datacite.org/dois'
    DATACITE_TEST_API = 'https://api.test.datacite.org/dois'

    def initialize
      @enabled = Setting.plugin_redmine_lab_flow['enable_doi_minting'] == '1'
      @test_mode = Setting.plugin_redmine_lab_flow['doi_test_mode'] == '1'
      @prefix = Setting.plugin_redmine_lab_flow['doi_prefix']
      @repository_id = Setting.plugin_redmine_lab_flow['datacite_repository_id']
      @password = Setting.plugin_redmine_lab_flow['datacite_password']
    end

    def mint(issue, metadata)
      unless @enabled
        raise 'DOI minting is not enabled. Please configure DataCite credentials in plugin settings.'
      end

      unless @prefix.present? && @repository_id.present? && @password.present?
        raise 'DataCite credentials not configured. Please set DOI prefix, repository ID, and password in plugin settings.'
      end

      suffix = generate_suffix(issue)
      doi = "#{@prefix}/#{suffix}"

      payload = build_datacite_payload(doi, issue, metadata)

      response = submit_to_datacite(payload)

      if response[:success]
        doi
      else
        raise "DOI minting failed: #{response[:error]}"
      end
    end

    def configured?
      @enabled && @prefix.present? && @repository_id.present? && @password.present?
    end

    def test_connection
      return { success: false, error: 'Not configured' } unless configured?

      uri = URI("#{api_endpoint.sub('/dois', '/repositories/#{@repository_id}')}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request.basic_auth(@repository_id, @password)

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        { success: true, repository: JSON.parse(response.body) }
      else
        { success: false, error: "HTTP #{response.code}: #{response.body}" }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    private

    def api_endpoint
      @test_mode ? DATACITE_TEST_API : DATACITE_API
    end

    def generate_suffix(issue)
      timestamp = Time.current.strftime('%Y%m%d')
      "#{issue.project.identifier.gsub(/[^a-z0-9]/i, '')}-#{issue.id}-#{timestamp}"
    end

    def build_datacite_payload(doi, issue, metadata)
      {
        data: {
          type: 'dois',
          attributes: {
            doi: doi,
            event: 'publish',
            creators: [{
              name: issue.author.name,
              nameType: 'Personal',
              nameIdentifiers: metadata.orcid_creator.present? ? [{
                nameIdentifier: "https://orcid.org/#{metadata.orcid_creator}",
                nameIdentifierScheme: 'ORCID',
                schemeUri: 'https://orcid.org'
              }] : []
            }],
            titles: [{
              title: issue.subject
            }],
            publisher: issue.project.name,
            publicationYear: issue.created_on.year,
            types: {
              resourceTypeGeneral: 'Dataset',
              resourceType: metadata.schema_org_type || 'Dataset'
            },
            descriptions: issue.description.present? ? [{
              description: issue.description,
              descriptionType: 'Abstract'
            }] : [],
            subjects: metadata.keywords.map { |k| { subject: k } },
            rightsList: metadata.license.present? ? [{
              rights: LabFlowFairMetadata::LICENSES[metadata.license],
              rightsUri: license_uri(metadata.license),
              rightsIdentifier: metadata.license
            }] : [],
            dates: [
              { date: issue.created_on.iso8601, dateType: 'Created' },
              { date: issue.updated_on.iso8601, dateType: 'Updated' }
            ],
            url: issue_url(issue)
          }
        }
      }
    end

    def submit_to_datacite(payload)
      uri = URI(api_endpoint)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/vnd.api+json'
      request.basic_auth(@repository_id, @password)
      request.body = payload.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPCreated)
        { success: true, response: JSON.parse(response.body) }
      else
        { success: false, error: "HTTP #{response.code}: #{response.body}" }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def license_uri(license_code)
      case license_code
      when 'CC0' then 'https://creativecommons.org/publicdomain/zero/1.0/'
      when 'CC-BY-4.0' then 'https://creativecommons.org/licenses/by/4.0/'
      when 'CC-BY-SA-4.0' then 'https://creativecommons.org/licenses/by-sa/4.0/'
      when 'CC-BY-NC-4.0' then 'https://creativecommons.org/licenses/by-nc/4.0/'
      when 'MIT' then 'https://opensource.org/licenses/MIT'
      when 'Apache-2.0' then 'https://www.apache.org/licenses/LICENSE-2.0'
      else nil
      end
    end

    def issue_url(issue)
      Rails.application.routes.url_helpers.issue_url(
        issue,
        host: Setting.host_name,
        protocol: Setting.protocol
      )
    rescue StandardError
      nil
    end
  end
end
