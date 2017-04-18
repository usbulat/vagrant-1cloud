require 'vagrant-1cloud/helpers/client'

module VagrantPlugins
  module OneCloud
    module Actions
      class ShutDown
        include Helpers::Client

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::shut_down')
        end

        def call(env)
          # submit shutdown droplet request
          result = @client.post("/server/#{@machine.id}/action", {
            :Type => 'ShutDownGuestOS'
          })

          # wait for request to complete
          env[:ui].info I18n.t('vagrant_1cloud.info.shutting_down')
          @client.wait_for_event(env, @machine.id, result['body']['ID'])

          # refresh droplet state with provider
          Provider.droplet(@machine, :refresh => true)

          @app.call(env)
        end
      end
    end
  end
end

