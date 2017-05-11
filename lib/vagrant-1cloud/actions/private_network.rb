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
            lockfile = "/tmp/" + net.to_s + ".lock"
            f = File.open(lockfile, "w+")

            retryable(:tries => 400, :sleep => 10) do
              next if env[:interrupted]
              raise 'Problem with lockfile' if check_file_locked?(lockfile)
            end

            f.flock(File::LOCK_EX)

            # Getting private network by name
            result = @client.request('/network')
            private_network = result['body'].find { |network| network['Name'] == net.to_s }

            # Creating private network if it doesn't exist
            if !private_network
              result = @client.post("/network", {
                  :Name => net,
                  :IsDHCP => false,
                  :DCLocation => @machine.provider_config.region
              })
              # Waiting for private network to create
              env[:ui].info I18n.t('vagrant_1cloud.info.creating_private_network')
              @client.wait_for_network(env, result['body']['ID'])

              result = @client.request("/network/#{result['body']['ID']}")
              private_network = result['body']
            end

            f.flock(File::LOCK_UN)

            # Adding server to specified network
            result = @client.post("/Server/#{@machine.id}/Action", {
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

            # set private and public network
            @machine.communicate.execute(<<-BASH)
                ifdown -a              
                
                export INTERFACE=eth0
                export MATCHADDR=$(ifconfig -a | grep eth0 | awk '{print $NF}')
                export MATCHID=$(udevadm info /sys/class/net/eth0 | grep P: | awk -F/ '{print $(NF-2)}')
                /lib/udev/write_net_rules
                
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

            # reset username
            @machine.config.ssh.username = user
          end

          @app.call(env)
        end

        def check_file_locked?(file)
          f = File.open(file, File::CREAT)
          Timeout::timeout(0.001) { f.flock(File::LOCK_EX) }
          f.flock(File::LOCK_UN)
          false
        rescue
          true
        ensure
          f.close
        end
      end
    end
  end
end
