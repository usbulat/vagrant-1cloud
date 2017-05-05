require 'vagrant-1cloud/helpers/client'

module VagrantPlugins
  module OneCloud
    module Actions
      class Reload
        include Helpers::Client

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
          $reboot_num = 3
          $check_num = 30
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
                raise 'No ssh connection'
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


