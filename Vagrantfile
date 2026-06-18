# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Common provisioning
  config.vm.provision "shell", inline: <<-SHELL
    pacman -Syu --noconfirm
    pacman -S --noconfirm jq curl zstd fakeroot sudo base-devel git
  SHELL

  config.vm.synced_folder ".", "/build", type: "rsync"

  # Arch Linux
  config.vm.define "arch", primary: true do |arch|
    arch.vm.box = "archlinux/archlinux"
    arch.vm.hostname = "amnezia-builder-arch"
    arch.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 2
    end
  end

  # Debian / Ubuntu
  config.vm.define "debian", autostart: false do |debian|
    debian.vm.box = "debian/bookworm64"
    debian.vm.hostname = "amnezia-builder-deb"
    debian.vm.provision "shell", inline: <<-SHELL
      apt-get update && apt-get install -y jq curl dpkg-dev fakeroot
    SHELL
    debian.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
    end
  end

  # Fedora
  config.vm.define "fedora", autostart: false do |fedora|
    fedora.vm.box = "fedora/41-cloud-base"
    fedora.vm.hostname = "amnezia-builder-rpm"
    fedora.vm.provision "shell", inline: <<-SHELL
      dnf install -y jq curl rpm-build fakeroot
    SHELL
    fedora.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
    end
  end
end
