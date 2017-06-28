require 'vagrant-1cloud/helpers/client'

module VagrantPlugins
  module OneCloud
    module Actions
      class SetupKey
        include Helpers::Client

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @client = client
          @logger = Log4r::Logger.new('vagrant::onecloud::setup_key')
        end

        # TODO check the content of the key to see if it has changed
        def call(env)
          ssh_key_name = @machine.provider_config.ssh_key_name

          begin
            # assigns existing ssh key id to env for use by other commands
            env[:ssh_key_id] = @client
                                   .request('/sshkey')
                                   .find_id(:body, :Title => ssh_key_name)

            env[:ui].info I18n.t('vagrant_1cloud.info.using_key', {
                :name => ssh_key_name
            })
          rescue Errors::ResultMatchError
            env[:ssh_key_id] = create_ssh_key(ssh_key_name, env)
          end

          puts env[:ssh_key_id]

          @app.call(env)
        end

        private

        def create_ssh_key(name, env)
          # assumes public key exists on the same path as private key with .pub ext
          path = @machine.config.ssh.private_key_path
          path = path[0] if path.is_a?(Array)
          path = File.expand_path(path, @machine.env.root_path)
          pub_key = OneCloud.public_key(path)

          env[:ui].info I18n.t('vagrant_1cloud.info.creating_key', {
              :name => name
          })

          result = @client.post('/sshkey', {
              :Title => name,
              :PublicKey => pub_key
          })
          result['body']['ID']
        end
      end
    end
  end
end
