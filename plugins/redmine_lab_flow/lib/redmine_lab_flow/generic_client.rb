# frozen_string_literal: true

require 'net/http'
require 'json'

module RedmineLabFlow
  class GenericClient
    TIMEOUT = 60

    def initialize(external_system)
      @system = external_system
      @base_url = external_system.base_url.chomp('/')
    end

    def submit_job(job)
      endpoint = @system.configuration['submit_endpoint'] || '/submit'
      payload = {
        job_id: job.id,
        issue_id: job.issue_id,
        job_type: job.job_type,
        callback_url: callback_url(job),
        **job.input_parameters
      }

      result = post(endpoint, payload)

      { job_id: result['job_id'] || result['id'] || job.id.to_s }
    end

    def job_status(job_id)
      endpoint = @system.configuration['status_endpoint'] || "/status/#{job_id}"

      result = get(endpoint.gsub('{job_id}', job_id.to_s))

      {
        state: normalize_state(result['status'] || result['state']),
        output: result['output'] || result['result'],
        error: result['error'] || result['message']
      }
    rescue StandardError => e
      { state: 'unknown', error: e.message }
    end

    def cancel_job(job_id)
      endpoint = @system.configuration['cancel_endpoint'] || "/cancel/#{job_id}"

      delete(endpoint.gsub('{job_id}', job_id.to_s))
    rescue StandardError => e
      Rails.logger.warn "Failed to cancel job #{job_id}: #{e.message}"
      { status: 'error', message: e.message }
    end

    def get(path, params = {})
      uri = URI("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?

      http = build_http(uri)
      request = Net::HTTP::Get.new(uri)
      add_auth_headers(request)

      response = http.request(request)
      parse_response(response)
    end

    def post(path, payload)
      uri = URI("#{@base_url}#{path}")

      http = build_http(uri)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      add_auth_headers(request)
      request.body = payload.to_json

      response = http.request(request)
      parse_response(response)
    end

    def put(path, payload)
      uri = URI("#{@base_url}#{path}")

      http = build_http(uri)
      request = Net::HTTP::Put.new(uri)
      request['Content-Type'] = 'application/json'
      add_auth_headers(request)
      request.body = payload.to_json

      response = http.request(request)
      parse_response(response)
    end

    def delete(path)
      uri = URI("#{@base_url}#{path}")

      http = build_http(uri)
      request = Net::HTTP::Delete.new(uri)
      add_auth_headers(request)

      response = http.request(request)
      parse_response(response)
    end

    private

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      http
    end

    def add_auth_headers(request)
      case @system.auth_type
      when 'api_key'
        header_name = @system.configuration['api_key_header'] || 'X-API-Key'
        request[header_name] = @system.api_key if @system.api_key
      when 'basic'
        request.basic_auth(@system.api_key, @system.api_secret) if @system.api_key
      when 'oauth2'
        request['Authorization'] = "Bearer #{@system.api_key}" if @system.api_key
      end
    end

    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        raise "API error: HTTP #{response.code} - #{response.body}"
      end

      return {} if response.body.blank?

      JSON.parse(response.body)
    rescue JSON::ParserError
      { raw: response.body }
    end

    def normalize_state(state)
      case state.to_s.downcase
      when 'pending', 'queued', 'waiting', 'new'
        'pending'
      when 'running', 'processing', 'in_progress'
        'running'
      when 'completed', 'done', 'success', 'ok', 'finished'
        'completed'
      when 'failed', 'error', 'failure'
        'failed'
      when 'cancelled', 'canceled', 'aborted'
        'cancelled'
      else
        'unknown'
      end
    end

    def callback_url(job)
      Rails.application.routes.url_helpers.lab_flow_api_job_callback_url(
        host: Setting.host_name,
        protocol: Setting.protocol,
        external_job_id: job.id
      )
    rescue StandardError
      nil
    end
  end
end
