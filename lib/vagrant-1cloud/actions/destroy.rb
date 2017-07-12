require 'vagrant-1cloud/helpers/client'

module VagrantPlugins
  module OneCloud
    module Actions
      class Destroy
        include Helpers::Client

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::destroy')
        end

        def call(env)
          # submit destroy droplet request
          @client.delete("/server/#{@machine.id}")

          env[:ui].info I18n.t('vagrant_1cloud.info.destroying')
          @client.wait_for_destroy(env, @machine.id)

          # set the machine id to nil to cleanup local vagrant state
          @machine.id = nil

          @app.call(env)
        end
      end
    end
  end
end
