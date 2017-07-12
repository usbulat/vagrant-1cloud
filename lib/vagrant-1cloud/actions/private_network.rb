require 'vagrant-1cloud/helpers/client'
require 'timeout'

module VagrantPlugins
  module OneCloud
    module Actions
      class PrivateNetwork
        include Helpers::Client
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::private_network')
        end

        def call(env)
          # check if network name is set
          return @app.call(env) unless @machine.provider_config.private_net

          @machine.provider_config.private_net.each do |net, ip|
            # Getting private network by name
            result = @client.request('/network')
            private_network = result['body'].find { |network| network['Name'] == net.to_s }

            raise "Private network #{net} is not created" if !private_network

            # Checking if machine is already added to network
            result = @client.request("/server/#{@machine.id}")
            linked_network = result['body']['LinkedNetworks'].find { |network| network['NetworkID'] == private_network['ID'] }

            if linked_network
                env[:ui].info I18n.t('vagrant_1cloud.info.already_connected', network: net)
                next
            end

            # Adding server to specified network
            result = @client.post("/server/#{@machine.id}/Action", {
                :Type => "AddNetwork",
                :NetworkID => private_network['ID']
            })

            # Waiting for server to add to private network
            env[:ui].info I18n.t('vagrant_1cloud.info.setting_private_network')
            @client.wait_for_event(env, @machine.id, result['body']['ID'])

            # refresh droplet state with provider
            Provider.droplet(@machine, :refresh => true)

            result = @client.request("/server/#{@machine.id}")
            linked_network = result['body']['LinkedNetworks'].find { |network| network['NetworkID'] == private_network['ID'] }

            if !ip
              ip = linked_network['IP']
            end

            # override ssh username to root temporarily
            user = @machine.config.ssh.username
            @machine.config.ssh.username = 'root'

            # set private network rules
            if private_network['IsDHCP']
              @machine.communicate.execute(<<-BASH)
                ifdown -a
  
                export INTERFACE=$(ifconfig -a | grep #{linked_network['MAC']} | awk '{print $1}')
                export MATCHADDR=#{linked_network['MAC']}
                export MATCHID=$(ifconfig -a | grep #{linked_network['MAC']} | awk 'system("udevadm info /sys/class/net/" $1)' | grep P: | awk -F/ '{print $(NF-2)}')
                /lib/udev/write_net_rules
                udevadm control --reload-rules && udevadm trigger
                
                echo >> /etc/network/interfaces
                ifconfig -a | grep #{linked_network['MAC']} | awk '{print "auto " $1}' >> /etc/network/interfaces
                ifconfig -a | grep #{linked_network['MAC']} | awk '{print "iface " $1 " inet dhcp"}' >> /etc/network/interfaces
                
                ifup -a
              BASH
            else
              @machine.communicate.execute(<<-BASH)
                ifdown -a
  
                export INTERFACE=$(ifconfig -a | grep #{linked_network['MAC']} | awk '{print $1}')
                export MATCHADDR=#{linked_network['MAC']}
                export MATCHID=$(ifconfig -a | grep #{linked_network['MAC']} | awk 'system("udevadm info /sys/class/net/" $1)' | grep P: | awk -F/ '{print $(NF-2)}')
                /lib/udev/write_net_rules
                udevadm control --reload-rules && udevadm trigger
                
                echo >> /etc/network/interfaces
                ifconfig -a | grep #{linked_network['MAC']} | awk '{print "auto " $1}' >> /etc/network/interfaces
                ifconfig -a | grep #{linked_network['MAC']} | awk '{print "iface " $1 " inet static"}' >> /etc/network/interfaces
                echo "address #{ip}" >> /etc/network/interfaces
                echo "netmask #{private_network['Mask']}" >> /etc/network/interfaces
                
                ifup -a
              BASH
            end

            # reset username
            @machine.config.ssh.username = user
          end

          @app.call(env)
        end
      end
    end
  end
end
