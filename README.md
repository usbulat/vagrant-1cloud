1cloud Vagrant Provider
==============================

[![Gem](https://img.shields.io/gem/v/vagrant-1cloud.svg)](https://rubygems.org/gems/vagrant-1cloud)

`vagrant-1cloud` is a Vagrant provider plugin that supports the management of [1cloud](https://1cloud.ru) VPS.

Features include:
- Create and destroy VPS
- Power on and off VPS
- Provision a VPS with shell
- Setup a SSH public key for authentication
- Create a new user account during VPS creation
- Create private network
- Add VPS to private network
- Rebuild VPS


Install
-------
Install the provider plugin using the Vagrant command-line interface:

`vagrant plugin install vagrant-1cloud`


Configure
---------
Once the provider has been installed, you will need to configure your project to use it. See the following example for a basic multi-machine `Vagrantfile` implementation that manages two 1cloud VPS:

```ruby
Vagrant.configure('2') do |config|

  config.vm.define "vps1" do |config|
      config.vm.provider :onecloud do |provider, override|
        override.ssh.private_key_path = '~/.ssh/id_rsa'
        override.vm.box = 'onecloud'
        provider.token = 'YOUR TOKEN'
      end
  end
  
  config.vm.define "vps2" do |config|
      config.vm.provider :onecloud do |provider, override|
        override.ssh.private_key_path = '~/.ssh/id_rsa'
        override.vm.box = 'onecloud'
        provider.token = 'YOUR TOKEN'
      end
  end
  
end
```

**Configuration Requirements**
- You *must* specify the `override.ssh.private_key_path` to enable authentication with the VPS.
- You *must* specify your 1cloud Personal Access Token at `provider.token`.

**Supported Configuration Attributes**
The following attributes are available to further configure the provider:
- `provider.image`
    * A string representing the image ID to use when creating a new VPS. It defaults to `7` (ubuntu-14-04-x64).
- `provider.region`
    * A string representing the region to create the new VPS in. It defaults to `SdnSpb`.
- `provider.hdd`
    * A number representing the disk space (in GB) to use when creating a new VPS (e.g. 50). It defaults to 10.
- `provider.hdd_type`
    * A string representing the disk type to use when creating a new VPS (e.g. `SSD`). It defaults to `SAS`.
- `provider.cpu`
    * A number representing the amount of cores to use when creating a new VPS (e.g. 2). It defaults to 1.
- `provider.ram`
    * A number representing the RAM (in MB) to use when creating a new VPS (e.g. 1024). It defaults to 512.
- `provider.hi_perf`
    * A boolean flag indicating whether to use high performance pool or not. It defaults to `false`.
- `provider.private_net`
    * A hash representing the pair that indicates the private network name and IP address of a new VPS (e.g. {"testnet" => "192.168.1.10"} or {"testnet" => nil} to set IP address automatically). VPS isn't added to private network by default.
- `config.vm.synced_folder`
    * Supports both rsync__args and rsync__exclude, see the [Vagrant Docs](http://docs.vagrantup.com/v2/synced-folders/rsync.html) for more information. rsync__args default to `["--verbose", "--archive", "--delete", "-z", "--copy-links"]` and rsync__exclude defaults to `[".vagrant/"]`.

The provider will create a new user account with the specified SSH key for authorization if `config.ssh.username` is set.


Run
---
After creating your project's `Vagrantfile` with the required configuration
attributes described above, you may create a new VPS with the following
command:

    $ vagrant up --provider=onecloud

This command will create a new VPS, setup your SSH key for authentication,
create a new user account, and run the provisioners you have configured.

**Supported Commands**

The provider supports the following Vagrant sub-commands:
- `vagrant destroy` - Destroys the VPS instance.
- `vagrant ssh` - Logs into the VPS instance using the configured user account.
- `vagrant halt` - Powers off the VPS instance.
- `vagrant provision` - Runs the configured provisioners and rsyncs any specified `config.vm.synced_folder`.
- `vagrant reload` - Reboots the VPS instance.
- `vagrant status` - Outputs the status (active, off, not created) for the VPS instance.
- `vagrant create-network` - Creates private network.
- `vagrant add-network` - Adds VPS to specified private network.
- `vagrant rebuild` - Rebuilds the VPS.

Troubleshooting
---------------
Before submitting a GitHub issue, please ensure both Vagrant and vagrant-onecloud are fully up-to-date.
* For the latest Vagrant version, please visit the [Vagrant](https://www.vagrantup.com/) website
* To update Vagrant plugins, run the following command: `vagrant plugin update`

* `vagrant plugin install vagrant-onecloud` 
    * Installation on OS X may not working due to a SSL certificate problem, and you may need to specify a certificate path explicitly. To do so, run `ruby -ropenssl -e "p OpenSSL::X509::DEFAULT_CERT_FILE"`. Then, add the following environment variable to your `.bash_profile` script and `source` it: `export SSL_CERT_FILE=/usr/local/etc/openssl/cert.pem`.


FAQ
---

* The Chef provisioner is no longer supported by default. Please use the `vagrant-omnibus` plugin to install Chef on Vagrant-managed machines. This plugin provides control over the specific version of Chef to install.
