module VagrantPlugins
  module OneCloud
    module Actions
      class SetupUser
        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @logger = Log4r::Logger.new('vagrant::onecloud::setup_user')
        end

        def call(env)
          # check if a username has been specified
          return @app.call(env) unless @machine.config.ssh.username

          # override ssh username to root temporarily
          user = @machine.config.ssh.username
          @machine.config.ssh.username = 'root'

          env[:ui].info I18n.t('vagrant_1cloud.info.creating_user', {
            :user => user
          })

          # create user account
          @machine.communicate.execute(<<-BASH)
            groupadd "#{user}"
            useradd -m -d "/home/#{user}" -g "#{user}" -r "#{user}" -s "/bin/bash"
            chown #{user}:#{user} -R "/home/#{user}"
          BASH

          # grant user sudo access with no password requirement
          @machine.communicate.execute(<<-BASH)
            echo "#{user} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
          BASH

          # create the .ssh directory in the users home
          @machine.communicate.execute("su #{user} -c 'mkdir -p ~/.ssh'")

          # add the specified key to the authorized keys file
          path = @machine.config.ssh.private_key_path
          path = path[0] if path.is_a?(Array)
          path = File.expand_path(path, @machine.env.root_path)
          pub_key = OneCloud.public_key(path)
          @machine.communicate.execute(<<-BASH)
            touch /home/#{user}/.ssh/authorized_keys
            echo \"#{pub_key}\" >> /home/#{user}/.ssh/authorized_keys
            chown #{user}:#{user} -R /home/#{user}/.ssh
            chmod 600 /home/#{user}/.ssh/authorized_keys
          BASH

          # reset username
          @machine.config.ssh.username = user

          @app.call(env)
        end
      end
    end
  end
end
