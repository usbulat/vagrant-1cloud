require 'vagrant-1cloud/helpers/result'
require 'faraday'
require 'json'

module VagrantPlugins
  module OneCloud
    module Helpers
      module Client
        def client
          @client ||= ApiClient.new(@machine)
        end
      end

      class ApiClient
        include Vagrant::Util::Retryable

        def initialize(machine)
          @logger = Log4r::Logger.new('vagrant::onecloud::apiclient')
          @config = machine.provider_config
          @client = Faraday.new({
            :url => 'https://api.1cloud.ru/',
            :ssl => {
              :ca_file => @config.ca_path
            }
          })
        end

        def delete(path, params = {}, method = :delete)
          @client.request :url_encoded
          request(path, params, :delete)
        end

        def post(path, params = {}, method = :post)
          @client.headers['Content-Type'] = 'application/json'
          request(path, params, :post)
        end

        def request(path, params = {}, method = :get)
          begin
            @logger.info "Request: #{path}"
            result = @client.send(method) do |req|
              req.url path
              req.headers['Authorization'] = "Bearer #{@config.token}"
              req.body = params.to_json
            end
          rescue Faraday::Error::ConnectionFailed => e
            # TODO this is suspect but because faraday wraps the exception
            #      in something generic there doesn't appear to be another
            #      way to distinguish different connection errors :(
            if e.message =~ /certificate verify failed/
              raise Errors::CertificateError
            end
            raise e
          end

          unless method == :delete
            begin
              body = JSON.parse(%Q[{"body":#{result.body}}])
              @logger.info "Response: #{body}"
            rescue JSON::ParserError => e
              raise(Errors::JSONError, {
                :message => e.message,
                :path => path,
                :params => params,
                :response => result.body
              })
            end
          end

          unless /^2\d\d$/ =~ result.status.to_s
            raise(Errors::APIStatusError, {
              :path => path,
              :params => params,
              :status => result.status,
              :response => body.inspect
            })
          end

          Result.new(body)
        end

        def wait_for_event(env, m_id, id)
          retryable(:tries => 400, :sleep => 10) do
            # stop waiting if interrupted
            next if env[:interrupted]

            # check action status
            result = self.request("/server/#{m_id}/action/#{id}")

            yield result if block_given?
            raise 'Action is not completed' if result['body']['State'] != 'Completed'
          end
        end

        def wait_for_network(env, net_id)
          retryable(:tries => 400, :sleep => 10) do
            # stop waiting if interrupted
            next if env[:interrupted]

            # check network status
            result = self.request("/network/#{net_id}")

            yield result if block_given?
            raise 'Network is not active' if result['body']['State'] != 'Active'
          end
        end
      end
    end
  end
end
