require 'optparse'

module VagrantPlugins
  module OneCloud
    module Commands
      class AddNetwork < Vagrant.plugin('2', :command)

        # Show description when `vagrant list-commands` is triggered
        def self.synopsis
          "plugin: vagrant-1cloud: adds VPS to specific private network"
        end

        def execute
          options = {}

          optparse = OptionParser.new do |opts|
            opts.banner = 'Usage: vagrant add-network [vm-name] [options]'

            opts.on('-n', '--net NETNAME', 'Network name') do |net|
              options[:Net] = net
            end

            options[:IP] = nil
            opts.on('-i', '--ip [IP]', 'Private IP address') do |ip|
              options[:IP] = ip
            end

            opts.on('-h', '--help', 'Display this screen') do
              puts opts
              exit
            end
          end

          begin
            optparse.parse!
            mandatory = [:Net]
            missing = mandatory.select{ |param| options[param].nil? }
            unless missing.empty?
              raise OptionParser::MissingArgument.new(missing.join(', '))
            end
          rescue OptionParser::InvalidOption, OptionParser::MissingArgument
            puts $!.to_s
            puts optparse
            exit
          end

          argv = parse_options(optparse)

          with_target_vms(argv) do |machine|
            machine.provider_config.private_net = {options[:Net] => options[:IP]}
            machine.action(:addnet)
          end

          0
        end
      end
    end
  end
end