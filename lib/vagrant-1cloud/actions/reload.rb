require 'vagrant-1cloud/helpers/client'

module VagrantPlugins
  module OneCloud
    module Actions
      class Reload
        include Helpers::Client
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::reload')
        end

        def call(env)
          # submit reboot droplet request
          result = @client.post("/server/#{@machine.id}/action", {
            :Type => 'PowerReboot'
          })

          # wait for request to complete
          env[:ui].info I18n.t('vagrant_1cloud.info.reloading')
          @client.wait_for_event(env, @machine.id, result['body']['ID'])

          user = @machine.config.ssh.username
          @machine.config.ssh.username = 'root'

          # wait for ssh to be ready
          retryable(:tries => 120, :sleep => 10) do
            next if env[:interrupted]
            raise 'not ready' if !@machine.communicate.ready?
          end

          @machine.config.ssh.username = user

          @app.call(env)
        end
      end
    end
  end
end


