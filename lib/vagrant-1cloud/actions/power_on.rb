require 'vagrant-1cloud/helpers/client'

module VagrantPlugins
  module OneCloud
    module Actions
      class PowerOn
        include Helpers::Client

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::power_on')
        end

        def call(env)
          # submit power on droplet request
          result = @client.post("/server/#{@machine.id}/action", {
            :Type => 'PowerOn'
          })

          # wait for request to complete
          env[:ui].info I18n.t('vagrant_1cloud.info.powering_on')
          @client.wait_for_event(env, @machine.id, result['body']['ID'])

          # refresh droplet state with provider
          Provider.droplet(@machine, :refresh => true)

          user = @machine.config.ssh.username
          @machine.config.ssh.username = 'root'

          # wait for ssh to be ready
          $reboot_num = 3
          $check_num = 20
          $i = 0
          while $i <= $reboot_num do
            $j = 0
            while !@machine.communicate.ready? && $j < $check_num do
              env[:ui].info I18n.t('vagrant_1cloud.info.ssh_off')
              sleep 10
              $j += 1
            end

            if $j < $check_num
              env[:ui].info I18n.t('vagrant_1cloud.info.ssh_on')
              break
            else
              if $i < $reboot_num
                # submit reboot droplet request
                result = @client.post("/server/#{@machine.id}/action", {
                    :Type => 'PowerReboot'
                })

                # wait for request to complete
                env[:ui].info I18n.t('vagrant_1cloud.info.reloading')
                @client.wait_for_event(env, @machine.id, result['body']['ID'])

                $i += 1
              else
                raise 'not ready'
              end
            end
          end

          @machine.config.ssh.username = user

          @app.call(env)
        end
      end
    end
  end
end


