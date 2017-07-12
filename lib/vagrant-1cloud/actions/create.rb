require 'vagrant-1cloud/helpers/client'

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
          ssh_key_id = [env[:ssh_key_id]]

          # submit new droplet request
          result = @client.post('/server', {
            :HDD => @machine.provider_config.hdd,
            :HDDType => @machine.provider_config.hdd_type,
            :CPU => @machine.provider_config.cpu,
            :RAM => @machine.provider_config.ram,
            :DCLocation => @machine.provider_config.region,
            :ImageID => @machine.provider_config.image,
            :Name => @machine.name,
            :SshKeys => ssh_key_id,
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

          user = @machine.config.ssh.username
          @machine.config.ssh.username = 'root'

          # wait for ssh to be ready
          env[:ui].info I18n.t('vagrant_1cloud.info.ssh')
          @client.wait_for_ssh(env, 3, 30)

          # change authorized_keys file permissions, host name and set public network rules
          @machine.communicate.execute(<<-BASH)
            chmod 600 ~/.ssh/authorized_keys          

            sed -i -e "s/127.0.1.1.*/127.0.1.1\t#{@machine.config.vm.hostname}/" /etc/hosts
            sed -i -e "s/#{droplet['IP']}.*/#{droplet['IP']}\t#{@machine.config.vm.hostname}/" /etc/hosts
            echo #{@machine.config.vm.hostname} > /etc/hostname
            hostname #{@machine.config.vm.hostname}

            ifdown -a
            export INTERFACE=eth0
            export MATCHADDR=$(ifconfig eth0 | awk 'NR==1{print $NF}')
            export MATCHID=$(udevadm info /sys/class/net/eth0 | grep P: | awk -F/ '{print $(NF-2)}')
            /lib/udev/write_net_rules
            udevadm control --reload-rules && udevadm trigger
            ifup -a
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
