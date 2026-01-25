# frozen_string_literal: true

require 'net/http'
require 'json'

module RedmineLabFlow
  class GalaxyClient
    TIMEOUT = 60

    def initialize(external_system)
      @system = external_system
      @base_url = external_system.base_url.chomp('/')
      @api_key = external_system.api_key
    end

    def workflows
      get('/api/workflows')
    end

    def workflow(workflow_id)
      get("/api/workflows/#{workflow_id}")
    end

    def submit_job(job)
      workflow_id = job.input_parameters['workflow_id']
      inputs = job.input_parameters['inputs'] || {}
      history_id = job.input_parameters['history_id']

      history_id ||= create_history("LabFlow Job #{job.id}")['id']

      payload = {
        workflow_id: workflow_id,
        history_id: history_id,
        inputs: inputs
      }

      result = post('/api/workflows', payload)

      { job_id: result['id'], history_id: history_id }
    end

    def job_status(job_id)
      result = get("/api/jobs/#{job_id}")

      state = case result['state']
              when 'new', 'queued', 'waiting'
                'pending'
              when 'running'
                'running'
              when 'ok'
                'completed'
              when 'error', 'deleted'
                'failed'
              else
                'unknown'
              end

      {
        state: state,
        raw_state: result['state'],
        output: result['outputs'],
        error: result['stderr']
      }
    end

    def job_results(job_id)
      get("/api/jobs/#{job_id}/outputs")
    end

    def cancel_job(job_id)
      delete("/api/jobs/#{job_id}")
    end

    def create_history(name)
      post('/api/histories', { name: name })
    end

    def upload_file(history_id, file_path, file_type: 'auto')
      uri = URI("#{@base_url}/api/tools")

      request = Net::HTTP::Post.new(uri)
      request['X-API-KEY'] = @api_key if @api_key

      boundary = SecureRandom.hex(16)
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"

      body = []
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"tool_id\"\r\n\r\n"
      body << "upload1\r\n"
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"history_id\"\r\n\r\n"
      body << "#{history_id}\r\n"
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"files_0|file_data\"; filename=\"#{File.basename(file_path)}\"\r\n"
      body << "Content-Type: application/octet-stream\r\n\r\n"
      body << File.read(file_path)
      body << "\r\n--#{boundary}--\r\n"

      request.body = body.join

      http = build_http(uri)
      response = http.request(request)

      parse_response(response)
    end

    def download_dataset(history_id, dataset_id)
      get("/api/histories/#{history_id}/contents/#{dataset_id}/display")
    end

    private

    def get(path)
      uri = URI("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(key: @api_key) if @api_key

      http = build_http(uri)
      request = Net::HTTP::Get.new(uri)
      request['X-API-KEY'] = @api_key if @api_key

      response = http.request(request)
      parse_response(response)
    end

    def post(path, payload)
      uri = URI("#{@base_url}#{path}")

      http = build_http(uri)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['X-API-KEY'] = @api_key if @api_key
      request.body = payload.to_json

      response = http.request(request)
      parse_response(response)
    end

    def delete(path)
      uri = URI("#{@base_url}#{path}")

      http = build_http(uri)
      request = Net::HTTP::Delete.new(uri)
      request['X-API-KEY'] = @api_key if @api_key

      response = http.request(request)
      parse_response(response)
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      http
    end

    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        raise "Galaxy API error: HTTP #{response.code} - #{response.body}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError
      response.body
    end
  end
end
