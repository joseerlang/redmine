# frozen_string_literal: true

require 'net/http'
require 'openssl'

module RedmineLabFlow
  class WebhookDispatcher
    TIMEOUT = 30
    MAX_RETRIES = 3

    class << self
      def dispatch(webhook, payload)
        new(webhook).dispatch(payload)
      end

      def trigger_event(project, event_type, data)
        webhooks = LabFlowWebhook.active.for_project(project).for_event(event_type)

        webhooks.each do |webhook|
          begin
            dispatch(webhook, webhook.render_payload(data))
            webhook.record_success!
          rescue StandardError => e
            webhook.record_failure!(e.message)
            Rails.logger.error "Webhook #{webhook.id} failed: #{e.message}"
          end
        end
      end
    end

    def initialize(webhook)
      @webhook = webhook
    end

    def dispatch(payload)
      uri = URI(@webhook.target_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request['User-Agent'] = 'RedmineLabFlow/1.0'
      request['X-LabFlow-Event'] = @webhook.event_type
      request['X-LabFlow-Delivery'] = SecureRandom.uuid

      if @webhook.secret_token.present?
        body = payload.is_a?(String) ? payload : payload.to_json
        signature = generate_signature(body, @webhook.secret_token)
        request['X-LabFlow-Signature'] = "sha256=#{signature}"
      end

      request.body = payload.is_a?(String) ? payload : payload.to_json

      response = with_retries { http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        raise "HTTP #{response.code}: #{response.message}"
      end

      {
        status: response.code.to_i,
        body: response.body
      }
    end

    private

    def generate_signature(payload, secret)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, payload)
    end

    def with_retries
      retries = 0
      begin
        yield
      rescue StandardError => e
        retries += 1
        if retries <= @webhook.retry_count
          sleep(2 ** retries)
          retry
        end
        raise
      end
    end
  end
end
