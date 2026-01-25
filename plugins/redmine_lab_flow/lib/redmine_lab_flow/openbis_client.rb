# frozen_string_literal: true

require 'net/http'
require 'json'

module RedmineLabFlow
  class OpenBISClient
    TIMEOUT = 60

    def initialize(external_system)
      @system = external_system
      @base_url = external_system.base_url.chomp('/')
      @session_token = nil
    end

    def login
      payload = {
        method: 'login',
        params: [@system.api_key, @system.api_secret],
        id: '1',
        jsonrpc: '2.0'
      }

      result = json_rpc('/openbis/openbis/rmi-application-server-v3.json', payload)
      @session_token = result['result']
    end

    def submit_job(job)
      ensure_session

      sample_type = job.input_parameters['sample_type'] || 'GENERAL_SAMPLE'
      space_code = job.input_parameters['space_code']
      project_code = job.input_parameters['project_code']
      properties = job.input_parameters['properties'] || {}

      sample = create_sample(
        type: sample_type,
        space: space_code,
        project: project_code,
        properties: properties
      )

      { job_id: sample['permId']['permId'] }
    end

    def job_status(perm_id)
      ensure_session

      sample = get_sample(perm_id)

      {
        state: sample ? 'completed' : 'failed',
        output: sample,
        error: sample ? nil : 'Sample not found'
      }
    end

    def create_sample(type:, space:, project: nil, properties: {})
      payload = {
        method: 'createSamples',
        params: [
          @session_token,
          [{
            '@type' => 'as.dto.sample.create.SampleCreation',
            typeId: { '@type' => 'as.dto.entitytype.id.EntityTypePermId', permId: type },
            spaceId: { '@type' => 'as.dto.space.id.SpacePermId', permId: space },
            projectId: project ? { '@type' => 'as.dto.project.id.ProjectPermId', permId: project } : nil,
            code: "LABFLOW_#{Time.current.to_i}",
            properties: properties
          }.compact]
        ],
        id: SecureRandom.uuid,
        jsonrpc: '2.0'
      }

      result = json_rpc('/openbis/openbis/rmi-application-server-v3.json', payload)
      result['result']&.first
    end

    def get_sample(perm_id)
      payload = {
        method: 'getSamples',
        params: [
          @session_token,
          [{ '@type' => 'as.dto.sample.id.SamplePermId', permId: perm_id }],
          {
            '@type' => 'as.dto.sample.fetchoptions.SampleFetchOptions',
            type: { '@type' => 'as.dto.sample.fetchoptions.SampleTypeFetchOptions' },
            space: { '@type' => 'as.dto.space.fetchoptions.SpaceFetchOptions' },
            properties: { '@type' => 'as.dto.property.fetchoptions.PropertyFetchOptions' }
          }
        ],
        id: SecureRandom.uuid,
        jsonrpc: '2.0'
      }

      result = json_rpc('/openbis/openbis/rmi-application-server-v3.json', payload)
      result['result']&.values&.first
    end

    def upload_dataset(sample_perm_id, file_path, dataset_type: 'RAW_DATA')
      ensure_session

      payload = {
        method: 'createDataSets',
        params: [
          @session_token,
          [{
            '@type' => 'as.dto.dataset.create.DataSetCreation',
            typeId: { '@type' => 'as.dto.entitytype.id.EntityTypePermId', permId: dataset_type },
            sampleId: { '@type' => 'as.dto.sample.id.SamplePermId', permId: sample_perm_id },
            code: "DS_#{Time.current.to_i}"
          }]
        ],
        id: SecureRandom.uuid,
        jsonrpc: '2.0'
      }

      result = json_rpc('/openbis/openbis/rmi-application-server-v3.json', payload)
      result['result']&.first
    end

    def search_samples(criteria = {})
      ensure_session

      search_criteria = {
        '@type' => 'as.dto.sample.search.SampleSearchCriteria'
      }

      if criteria[:type]
        search_criteria['criteria'] = [{
          '@type' => 'as.dto.sample.search.SampleTypeSearchCriteria',
          'criteria' => [{
            '@type' => 'as.dto.common.search.CodeSearchCriteria',
            'fieldValue' => { '@type' => 'as.dto.common.search.StringEqualToValue', 'value' => criteria[:type] }
          }]
        }]
      end

      payload = {
        method: 'searchSamples',
        params: [
          @session_token,
          search_criteria,
          {
            '@type' => 'as.dto.sample.fetchoptions.SampleFetchOptions',
            type: { '@type' => 'as.dto.sample.fetchoptions.SampleTypeFetchOptions' },
            properties: { '@type' => 'as.dto.property.fetchoptions.PropertyFetchOptions' }
          }
        ],
        id: SecureRandom.uuid,
        jsonrpc: '2.0'
      }

      result = json_rpc('/openbis/openbis/rmi-application-server-v3.json', payload)
      result['result']&.dig('objects') || []
    end

    def cancel_job(job_id)
      { status: 'not_supported' }
    end

    private

    def ensure_session
      login if @session_token.nil?
    end

    def json_rpc(path, payload)
      uri = URI("#{@base_url}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "OpenBIS API error: HTTP #{response.code}"
      end

      result = JSON.parse(response.body)

      if result['error']
        raise "OpenBIS error: #{result['error']['message']}"
      end

      result
    end
  end
end
