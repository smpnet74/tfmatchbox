#!/bin/bash
set -x
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
echo BEGIN
date '+%Y-%m-%d %H:%M:%S'
apt-get -y install software-properties-common
apt-add-repository -y ppa:ansible/ansible
apt-get -y update
apt-get -y install ansible
cat << HEREDOCEOF > /home/ubuntu/matchbox_prep.yml
---
- hosts: all
  become: true
  tasks:
  - name: Install Pip
    apt:
      name: python-pip
  - name: Upgrade Pip to latest
    pip:
      name: pip
      extra_args: --upgrade
  - name: Install Pyasn1 Python package for xenial64 only
    pip:
      name: pyasn1
  - name: Install NDG-httpsclient Python package for xenial64 only
    pip:
      name: ndg-httpsclient
  - name: Apt key for docker gpg
    apt_key:
      url: "https://download.docker.com/linux/ubuntu/gpg"
      state: present
  - name: Apt repository stable for docker
    apt_repository:
      repo: deb https://download.docker.com/linux/ubuntu xenial stable
      state: present
  - name: Run the equivalent of apt-get update as a separate step
    apt:
      update_cache: yes
  - name: Install Docker Community Edition
    apt:
      name: docker-ce
  - name: Install Unzip
    apt:
      name: unzip
  - name: Remove useless packages from the apt cache
    apt:
      autoclean: yes
  - name: Remove apt dependencies that are no longer required
    apt:
      autoremove: yes
  - name: Install Docker-py via Pip
    pip:
      name: docker-py
  - name: Install Docker Compose via Pip
    pip:
      name: docker-compose
  - name: Download matchbox gzip
    get_url:
      url: https://github.com/coreos/matchbox/releases/download/v0.6.1/matchbox-v0.6.1-linux-amd64.tar.gz
      dest: /home/ubuntu
      mode: 0755
  - name: Extract matchbox gzip
    unarchive:
      src: /home/ubuntu/matchbox-v0.6.1-linux-amd64.tar.gz
      dest: /home/ubuntu
  - name: Create the necessary certs for the tectonic install
    shell: ./cert-gen
    creates: ca.crt
    environment:
      SAN: DNS.1:matchbox.disconnectedlab01.com
    args:
      chdir: /home/ubuntu/matchbox-v0.6.1-linux-amd64/scripts/tls
      creates: ca.crt
  - name: Create the matchbox cert dir
    file:
      path: /home/ubuntu/certs
      state: directory
      mode: 0755
  - name: Copy the certs to the matchbox cert dir
    copy:
      src: "{{ item }}"
      dest: /home/ubuntu/certs
      mode: 0755
    with_fileglob:
      - /home/ubuntu/matchbox-v0.6.1-linux-amd64/scripts/tls/client*
  - name: Copy the certs to the matchbox cert dir
    copy:
      src: "{{ item }}"
      dest: /home/ubuntu/certs
      mode: 0755
    with_fileglob:
      - /home/ubuntu/matchbox-v0.6.1-linux-amd64/scripts/tls/ca.c*
  - name: Create the /etc/matchbox directory
    file:
      path: /etc/matchbox
      state: directory
      mode: 0755
  - name: Create the /var/lib/matchbox/ directory
    file:
      path: /var/lib/matchbox
      state: directory
      mode: 0755
  - name: Create the /var/lib/matchbox/assets directory
    file:
      path: /var/lib/matchbox/assets
      state: directory
      mode: 0755
  - name: Copy the server certs to /etc/matchbox
    copy:
      src: "{{ item }}"
      dest: /etc/matchbox
      mode: 0755
    with_fileglob:
      - /home/ubuntu/matchbox-v0.6.1-linux-amd64/scripts/tls/server*
  - name: Copy the ca.crt to /etc/matchbox
    copy:
      src: "{{ item }}"
      dest: /etc/matchbox
      mode: 0755
    with_fileglob:
      - /home/ubuntu/matchbox-v0.6.1-linux-amd64/scripts/tls/ca.c*
  - name: Download the 1465.8.0 CoreOS assets
    shell: ./get-coreos stable 1465.8.0 .
    args:
      chdir: /home/ubuntu/matchbox-v0.6.1-linux-amd64/scripts
      creates: coreos
  - name: Copy the coreos assets directory to /var/lib/matchbox/assets
    copy: 
      src: /home/ubuntu/matchbox-v0.6.1-linux-amd64/scripts/coreos
      dest: /var/lib/matchbox/assets/
      directory_mode: yes
HEREDOCEOF
chmod 755 /home/ubuntu/matchbox_prep.yml
sudo ansible-playbook -i "localhost," -c local /home/ubuntu/matchbox_prep.yml
