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

      provider(:onecloud, parallel: false, defaultable: false) do
        require_relative 'provider'
        Provider
      end
    end
  end
end
