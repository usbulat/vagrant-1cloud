require 'vagrant-1cloud/actions/check_state'
require 'vagrant-1cloud/actions/create'
require 'vagrant-1cloud/actions/destroy'
require 'vagrant-1cloud/actions/shut_down'
require 'vagrant-1cloud/actions/power_off'
require 'vagrant-1cloud/actions/power_on'
require 'vagrant-1cloud/actions/reload'
require 'vagrant-1cloud/actions/setup_user'
require 'vagrant-1cloud/actions/modify_provision_path'
require 'vagrant-1cloud/actions/private_network'
require 'vagrant-1cloud/actions/rebuild'
require 'vagrant-1cloud/actions/setup_sudo'
require 'vagrant-1cloud/actions/setup_key'

module VagrantPlugins
  module OneCloud
    module Actions
      include Vagrant::Action::Builtin

      def self.destroy
        return Vagrant::Action::Builder.new.tap do |builder|
          builder.use ConfigValidate
          builder.use Call, CheckState do |env, b|
            case env[:machine_state]
            when :not_created
              env[:ui].info I18n.t('vagrant_1cloud.info.not_created')
            else
              b.use Call, DestroyConfirm do |env2, b2|
                if env2[:result]
                  b2.use Destroy
                  b2.use ProvisionerCleanup if defined?(ProvisionerCleanup)
                end
              end
            end
          end
        end
      end

      def self.ssh
        return Vagrant::Action::Builder.new.tap do |builder|
          builder.use ConfigValidate
          builder.use Call, CheckState do |env, b|
            case env[:machine_state]
            when :Active
              b.use SSHExec
            when :off
              env[:ui].info I18n.t('vagrant_1cloud.info.off')
            when :not_created
              env[:ui].info I18n.t('vagrant_1cloud.info.not_created')
            end
          end
        end
      end

      def self.ssh_run
        return Vagrant::Action::Builder.new.tap do |builder|
          builder.use ConfigValidate
          builder.use Call, CheckState do |env, b|
            case env[:machine_state]
              when :Active
                b.use SSHRun
              when :off
                env[:ui].info I18n.t('vagrant_1cloud.info.off')
              when :not_created
                env[:ui].info I18n.t('vagrant_1cloud.info.not_created')
            end
          end
        end
      end

      def self.provision
        return Vagrant::Action::Builder.new.tap do |builder|
          builder.use ConfigValidate
          builder.use Call, CheckState do |env, b|
            case env[:machine_state]
            when :Active
              b.use Provision
              b.use ModifyProvisionPath
              b.use SyncedFolders
            when :off
              env[:ui].info I18n.t('vagrant_1cloud.info.off')
            when :not_created
              env[:ui].info I18n.t('vagrant_1cloud.info.not_created')
            end
          end
        end
      end

      def self.up
        return Vagrant::Action::Builder.new.tap do |builder|
          builder.use ConfigValidate
          builder.use Call, CheckState do |env, b|
            case env[:machine_state]
            when :Active
              env[:ui].info I18n.t('vagrant_1cloud.info.already_active')
            when :off
              b.use PowerOn
              b.use provision
            when :not_created
              b.use SetupKey
              b.use Create
              b.use PrivateNetwork
              b.use SetupSudo
              b.use SetupUser
              b.use provision
            end
          end
        end
      end

      def self.halt
        return Vagrant::Action::Builder.new.tap do |builder|
          builder.use ConfigValidate
          builder.use Call, CheckState do |env, b|
            case env[:machine_state]
            when :Active
              if env[:force_halt] 
                b.use PowerOff
              else
                b.use ShutDown
              end
            when :off
              env[:ui].info I18n.t('vagrant_1cloud.info.already_off')
            when :not_created
              env[:ui].info I18n.t('vagrant_1cloud.info.not_created')
            end
          end
        end
      end

      def self.reload
        return Vagrant::Action::Builder.new.tap do |builder|
          builder.use ConfigValidate
          builder.use Call, CheckState do |env, b|
            case env[:machine_state]
            when :Active
              b.use Reload
              b.use provision
            when :off
              env[:ui].info I18n.t('vagrant_1cloud.info.off')
            when :not_created
              env[:ui].info I18n.t('vagrant_1cloud.info.not_created')
            end
          end
        end
      end

      def self.rebuild
        return Vagrant::Action::Builder.new.tap do |builder|
          builder.use ConfigValidate
          builder.use Call, CheckState do |env, b|
            case env[:machine_state]
              when :Active, :off
                b.use Rebuild
                b.use PrivateNetwork
                b.use SetupSudo
                b.use SetupUser
                b.use provision
              when :not_created
                env[:ui].info I18n.t('vagrant_1cloud.info.not_created')
            end
          end
        end
      end
    end
  end
end
