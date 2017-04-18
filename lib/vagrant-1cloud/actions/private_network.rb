require 'vagrant-1cloud/helpers/client'

module VagrantPlugins
  module OneCloud
    module Actions
      class PrivateNetwork
        include Helpers::Client

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::private_network')
        end

        def call(env)
          # check if network name is set
          return @app.call(env) unless @machine.provider_config.net_name

          result = @client.request('/network')
          private_network = result['body'].find { |network| network['Name'] == @machine.provider_config.net_name.to_s }

          if !private_network
            result = @client.post("/network", {
                :Name => @machine.provider_config.net_name,
                :IsDHCP => false,
                :DCLocation => @machine.provider_config.region
            })
            env[:ui].info I18n.t('vagrant_1cloud.info.creating_private_network')
            @client.wait_for_network(env, result['body']['ID'])

            result = @client.request("/network/#{result['body']['ID']}")
            private_network = result['body']
          end

          result = @client.post("/Server/#{@machine.id}/Action", {
              :Type => "AddNetwork",
              :NetworkID => private_network['ID']
          })

          env[:ui].info I18n.t('vagrant_1cloud.info.setting_private_network')
          @client.wait_for_event(env, @machine.id, result['body']['ID'])

          # refresh droplet state with provider
          Provider.droplet(@machine, :refresh => true)

          result = @client.request("/server/#{@machine.id}")
          linked_network = result['body']['LinkedNetworks'].find { |network| network['NetworkID'] == private_network['ID'] }

          if !@machine.provider_config.private_ip
            @machine.provider_config.private_ip = linked_network['IP']
          end

          # override ssh username to root temporarily
          user = @machine.config.ssh.username
          @machine.config.ssh.username = 'root'

          # set private network
          @machine.communicate.execute(<<-BASH)
              echo >> /etc/network/interfaces
              ifconfig -a | grep #{linked_network['MAC']} | awk '{print "auto " $1}' >> /etc/network/interfaces
              ifconfig -a | grep #{linked_network['MAC']} | awk '{print "iface " $1 " inet static"}' >> /etc/network/interfaces
              echo "address #{@machine.provider_config.private_ip}" >> /etc/network/interfaces
              echo "netmask #{private_network['Mask']}" >> /etc/network/interfaces
              ifconfig -a | grep #{linked_network['MAC']} | awk '{system("ifdown "$1" && ifup "$1)}'
          BASH

          # reset username
          @machine.config.ssh.username = user

          @app.call(env)
        end
      end
    end
  end
end
