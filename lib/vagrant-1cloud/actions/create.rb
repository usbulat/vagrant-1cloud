require 'vagrant-1cloud/helpers/client'
require 'net/ssh'

module VagrantPlugins
  module OneCloud
    module Actions
      class Create
        include Helpers::Client

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::create')
        end

        def call(env)
          # submit new droplet request
          result = @client.post('/server', {
            :HDD => @machine.provider_config.hdd,
            :HDDType => @machine.provider_config.hdd_type,
            :CPU => @machine.provider_config.cpu,
            :RAM => @machine.provider_config.ram,
            :DCLocation => @machine.provider_config.region,
            :ImageID => @machine.provider_config.image,
            :Name => @machine.config.vm.hostname || @machine.name,
            :isHighPerformance => @machine.provider_config.hi_perf
          }.delete_if { |k, v| v.nil? })
          
          # assign the machine id for reference in other commands
          @machine.id = result['body']['ID'].to_s

          # wait for request to complete
          result = @client.request("/server/#{@machine.id}/action")
          env[:ui].info I18n.t('vagrant_1cloud.info.creating')
          @client.wait_for_event(env, @machine.id, result['body'].first['ID'])

          # refresh droplet state with provider
          droplet = Provider.droplet(@machine, :refresh => true)

          # add public key to machine
          path = @machine.config.ssh.private_key_path
          path = path[0] if path.is_a?(Array)
          path = File.expand_path(path, @machine.env.root_path)
          pub_key = OneCloud.public_key(path)
          Net::SSH.start(droplet['IP'], droplet['AdminUserName'], :password => droplet['AdminPassword']) do |ssh|
            ssh.exec!("mkdir ~/.ssh")
            ssh.exec!("touch ~/.ssh/authorized_keys")
            ssh.exec!("echo \"#{pub_key}\" >> ~/.ssh/authorized_keys")
          end

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

          # change host name
          @machine.communicate.execute(<<-BASH)
            sed -i -e "s/127.0.1.1.*/127.0.1.1\t#{@machine.config.vm.hostname}/" /etc/hosts
            sed -i -e "s/#{droplet['IP']}.*/#{droplet['IP']}\t#{@machine.config.vm.hostname}/" /etc/hosts
            echo #{@machine.config.vm.hostname} > /etc/hostname
            hostname #{@machine.config.vm.hostname}
          BASH

          @machine.config.ssh.username = user

          @app.call(env)
        end

        # Both the recover and terminate are stolen almost verbatim from
        # the Vagrant AWS provider up action
        def recover(env)
          return if env['vagrant.error'].is_a?(Vagrant::Errors::VagrantError)

          if @machine.state.id != :not_created
            terminate(env)
          end
        end

        def terminate(env)
          destroy_env = env.dup
          destroy_env.delete(:interrupted)
          destroy_env[:config_validate] = false
          destroy_env[:force_confirm_destroy] = true
          env[:action_runner].run(Actions.destroy, destroy_env)
        end
      end
    end
  end
end
