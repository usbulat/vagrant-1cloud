module VagrantPlugins
  module OneCloud
    class Plugin < Vagrant.plugin('2')
      name 'OneCloud'
      description <<-DESC
        This plugin installs a provider that allows Vagrant to manage
        machines using 1cloud's API.
      DESC

      config(:onecloud, :provider) do
        require_relative 'config'
        Config
      end

      provider(:onecloud, parallel: true, defaultable: false) do
        require_relative 'provider'
        Provider
      end

      command(:rebuild) do
        require_relative 'commands/rebuild'
        Commands::Rebuild
      end

      command("add-network") do
        require_relative 'commands/add_network'
        Commands::AddNetwork
      end

      command("create-network") do
        require_relative 'commands/create_network'
        Commands::CreateNetwork
      end
    end
  end
end