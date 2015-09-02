# -*- mode: ruby -*-
# vi: set ft=ruby :

# This Vagrant file creates and provisions a VM used for development
# of the NHM data portal. It provisions in a single VM:
# - The database server (postgres) ;
# - The Solr server ;
# - The application server (CKAN + extentions).


# VM Specific parameters
VM_NAME = 'ckan-import-server'
VM_MEMORY_LIMIT = "4096"
VM_CPU_LIMIT = "100"
VM_IP = "10.11.12.16"

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Base box
  config.vm.box = "precise64" 
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  config.vm.hostname = VM_NAME

  # This server should be on 10.11.12.16
  config.vm.network :private_network, ip: VM_IP
  config.vm.synced_folder ".", "/vagrant", :nfs => true

  # Update as needed for development needs
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", VM_MEMORY_LIMIT]
    vb.customize ["modifyvm", :id, "--cpuexecutioncap", VM_CPU_LIMIT]
  end

  # Call the provision scripts. This will set up all the services
  # on a single VM.
  config.vm.provision "shell",
    path: "provision/provision.sh",
    args: "-r /vagrant/provision"
end
