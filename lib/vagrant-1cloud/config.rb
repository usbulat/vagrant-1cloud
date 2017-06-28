module VagrantPlugins
  module OneCloud
    class Config < Vagrant.plugin('2', :config)
      attr_accessor :token
      attr_accessor :image
      attr_accessor :region
      attr_accessor :hdd
      attr_accessor :hdd_type
      attr_accessor :cpu
      attr_accessor :ram
      attr_accessor :hi_perf
      attr_accessor :ca_path
      attr_accessor :private_net
      attr_accessor :ssh_key_name

      def initialize
        @token              = UNSET_VALUE
        @image              = UNSET_VALUE
        @region             = UNSET_VALUE
        @hdd                = UNSET_VALUE
        @hdd_type           = UNSET_VALUE
        @cpu                = UNSET_VALUE
        @ram                = UNSET_VALUE
        @hi_perf            = UNSET_VALUE
        @ca_path            = UNSET_VALUE
        @private_net        = UNSET_VALUE
        @ssh_key_name       = UNSET_VALUE
      end

      def finalize!
        @token              = ENV['DO_TOKEN'] if @token == UNSET_VALUE
        @image              = '7' if @image == UNSET_VALUE
        @region             = 'SdnSpb' if @region == UNSET_VALUE
        @hdd                = '10' if @hdd == UNSET_VALUE
        @hdd_type           = 'SAS' if @hdd_type == UNSET_VALUE
        @cpu                = '1' if @cpu == UNSET_VALUE
        @ram                = '512' if @ram == UNSET_VALUE
        @hi_perf            = false if @hi_perf == UNSET_VALUE
        @ca_path            = nil if @ca_path == UNSET_VALUE
        @private_net        = nil if @private_net == UNSET_VALUE
        @ssh_key_name       = 'Vagrant' if @ssh_key_name == UNSET_VALUE
      end

      def validate(machine)
        errors = []
        errors << I18n.t('vagrant_1cloud.config.token') if !@token

        key = machine.config.ssh.private_key_path
        key = key[0] if key.is_a?(Array)
        if !key
          errors << I18n.t('vagrant_1cloud.config.private_key')
        elsif !File.file?(File.expand_path("#{key}.pub", machine.env.root_path))
          errors << I18n.t('vagrant_1cloud.config.public_key', {
            :key => "#{key}.pub"
          })
        end

        { '1cloud Provider' => errors }
      end
    end
  end
end