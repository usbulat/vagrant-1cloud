require 'vagrant-1cloud/helpers/client'
require 'net/ssh'

module VagrantPlugins
  module OneCloud
    module Actions
      class Rebuild
        include Helpers::Client
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::rebuild')
        end

        def call(env)

          # submit rebuild request
          result = @client.post("/server/#{@machine.id}/rebuild", {
              :ImageId => @machine.provider_config.image
          })

          # assign the machine id for reference in other commands
          @machine.id = result['body']['ID'].to_s

          # wait for request to complete
          result = @client.request("/server/#{@machine.id}/action")
          env[:ui].info I18n.t('vagrant_1cloud.info.rebuilding')
          @client.wait_for_event(env, @machine.id, result['body'].first['ID'])

          # refresh droplet state with provider
          droplet = Provider.droplet(@machine, :refresh => true)

          user = @machine.config.ssh.username
          @machine.config.ssh.username = 'root'

          # add public key to machine
          ssh_key_name = @machine.provider_config.ssh_key_name
          result = @client.request('/sshkey')
          pub_key = result['body'].find { |k| k['Title'] == ssh_key_name }

          Net::SSH.start(droplet['IP'], droplet['AdminUserName'], :password => droplet['AdminPassword']) do |ssh|
            ssh.exec!("mkdir ~/.ssh")
            ssh.exec!("touch ~/.ssh/authorized_keys")
            ssh.exec!("echo \"ssh-rsa #{pub_key['PublicKey']}\" >> ~/.ssh/authorized_keys")
            ssh.exec!("chmod 600 ~/.ssh/authorized_keys")
          end

          # wait for ssh to be ready
          env[:ui].info I18n.t('vagrant_1cloud.info.ssh')
          @client.wait_for_ssh(env, 3, 30)

          # change authorized_keys file permissions, host name and set public network rules
          @machine.communicate.execute(<<-BASH)
            sed -i -e "s/127.0.1.1.*/127.0.1.1\t#{@machine.config.vm.hostname}/" /etc/hosts
            sed -i -e "s/#{droplet['IP']}.*/#{droplet['IP']}\t#{@machine.config.vm.hostname}/" /etc/hosts
            echo #{@machine.config.vm.hostname} > /etc/hostname
            hostname #{@machine.config.vm.hostname}

            ifdown -a
            export INTERFACE=eth0
            export MATCHADDR=$(ifconfig -a | grep eth0 | awk '{print $NF}')
            export MATCHID=$(udevadm info /sys/class/net/eth0 | grep P: | awk -F/ '{print $(NF-2)}')
            /lib/udev/write_net_rules
            udevadm control --reload-rules && udevadm trigger
            ifup -a
          BASH

          @machine.config.ssh.username = user

          @app.call(env)
        end
      end
    end
  end
end
