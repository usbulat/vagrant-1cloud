require 'vagrant-1cloud/helpers/client'

module VagrantPlugins
  module OneCloud
    module Actions
      class PowerOff
        include Helpers::Client

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::power_off')
        end

        def call(env)
          # submit power off droplet request
          result = @client.post("/server/#{@machine.id}/action", {
            :Type => 'PowerOff'
          })

          # wait for request to complete
          env[:ui].info I18n.t('vagrant_1cloud.info.powering_off')
          @client.wait_for_event(env, @machine.id, result['body']['ID'])

          # refresh droplet state with provider
          Provider.droplet(@machine, :refresh => true)

          @app.call(env)
        end
      end
    end
  end
end

