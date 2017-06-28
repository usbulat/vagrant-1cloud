require 'optparse'
require 'vagrant-1cloud/helpers/result'
require 'faraday'
require 'json'

module VagrantPlugins
  module OneCloud
    module Commands
      class CreateNetwork < Vagrant.plugin('2', :command)
        include Helpers
        include Vagrant::Util::Retryable

        # Show description when `vagrant list-commands` is triggered
        def self.synopsis
          "plugin: vagrant-1cloud: creates new private network"
        end

        def execute
          options = {}

          optparse = OptionParser.new do |opts|
            opts.banner = 'Usage: vagrant create-network [options]'

            opts.on('-n', '--name NAME', 'Network name') do |name|
              options[:Name] = name
            end

            options[:IsDHCP] = false
            opts.on('-d', '--[no-]dhcp', "Use dhcp or not (default #{options[:IsDHCP]})") do |dhcp|
              options[:IsDHCP] = dhcp
            end

            opts.on('-l', '--location LOCATION', 'Network location') do |location|
              options[:DCLocation] = location
            end

            opts.on('-t', '--token TOKEN', '1cloud type token') do |token|
              options[:token] = token
            end

            opts.on('-h', '--help', 'Display this screen') do
              puts opts
              exit
            end
          end

          begin
            optparse.parse!
            mandatory = [:Name, :DCLocation, :token]
            missing = mandatory.select{ |param| options[param].nil? }
            unless missing.empty?
              raise OptionParser::MissingArgument.new(missing.join(', '))
            end
          rescue OptionParser::InvalidOption, OptionParser::MissingArgument
            puts $!.to_s
            puts optparse
            exit
          end

          result = request(options[:token], '/network')
          private_network = result['body'].find { |network| network['Name'] == options[:Name] }

          if private_network
            @env.ui.info I18n.t('vagrant_1cloud.info.network_exists', network: options[:Name])
          else
            @env.ui.info I18n.t('vagrant_1cloud.info.network_missing', network: options[:Name])

            result = request(options[:token], '/network', options.except(:token), :post)

            # Waiting for private network to create
            @env.ui.info I18n.t('vagrant_1cloud.info.creating_private_network')
            wait_for_network(options[:token], result['body']['ID'])
          end

          0
        end

        def request(token, path, params = {}, method = :get)
          connection = Faraday.new({
            :url => 'https://api.1cloud.ru/'
          })

          begin
            @env.ui.info I18n.t('vagrant_1cloud.info.request', path: path)
            @env.ui.info I18n.t('vagrant_1cloud.info.params', params: params)
            result = connection.send(method) do |req|
              req.url path
              req.headers['Authorization'] = "Bearer #{token}"
              req.body = params
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

          begin
            body = JSON.parse(%Q[{"body":#{result.body}}])
            @env.ui.info I18n.t('vagrant_1cloud.info.response', body: body)
          rescue JSON::ParserError => e
            raise(Errors::JSONError, {
                :message => e.message,
                :path => path,
                :params => params,
                :response => result.body
            })
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

        def wait_for_network(token, net_id)
          retryable(:tries => 400, :sleep => 10) do
            # check network status
            result = request(token, "/network/#{net_id}")
            raise 'Network is not active' if result['body']['State'] != 'Active'
          end
        end
      end
    end
  end
end