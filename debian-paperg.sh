#!/usr/bin/env sh

# This bootstraps Puppet on Debian
set -e

# Do the initial apt-get update
echo "Initial apt-get update..."
apt-get update >/dev/null

# Older versions of Debian don't have lsb_release by default, so 
# install that if we have to.
which lsb_release || apt-get install -y lsb-release

# Load up the release information
DISTRIB_CODENAME=$(lsb_release -c -s)

REPO_DEB_URL="http://apt.puppetlabs.com/puppetlabs-release-${DISTRIB_CODENAME}.deb"

# If wheezy ensure that dotdeb is included to install php 5.6
if [ "$DISTRIB_CODENAME" = "wheezy" ]; then
    wget https://www.dotdeb.org/dotdeb.gpg -P /tmp
    apt-key add /tmp/dotdeb.gpg

    debapt="deb http://packages.dotdeb.org wheezy-php56 all"
    debsrc="deb-src http://packages.dotdeb.org wheezy-php56 all"
    echo "$debapt" > /etc/apt/sources.list.d/dotdeb.list
    echo "$debsrc" >> /etc/apt/sources.list.d/dotdeb.list

    apt-get update
fi

#--------------------------------------------------------------------
# NO TUNABLES BELOW THIS POINT
#--------------------------------------------------------------------
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Install wget if we have to (some older Debian versions)
echo "Installing wget and curl..."
apt-get install -y wget curl >/dev/null

# Install other useful tools
echo "Installing common utilities..."
apt-get install -y git tmux vim

# Remove packages in base install we do not want
echo "Removing unused packages..."
apt-get remove -y nfs-common

# Set timezone to UTC
echo "Setting timezone to UTC..."
echo "Etc/UTC" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Install the PuppetLabs repo
echo "Configuring PuppetLabs repo..."
repo_deb_path=$(mktemp)
wget --output-document="${repo_deb_path}" "${REPO_DEB_URL}" 2>/dev/null
dpkg -i "${repo_deb_path}" >/dev/null
apt-get update >/dev/null

# Install Puppet
echo "Installing Puppet..."
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install puppet >/dev/null

echo "Puppet installed!"

echo "Customizing puppet.conf for PaperG"
grep paperg /etc/puppet/puppet.conf || sed -i '/\[main\]/a server=puppet.paperg.com\npluginsync=true' /etc/puppet/puppet.conf

echo "Configuring puppet to start"
DEFAULT_FILE="/etc/default/puppet"
if [ -f $DEFAULT_FILE ]
then
    sed -i 's/START=no/START=yes/' $DEFAULT_FILE
else
    echo 'START=yes' >> $DEFAULT_FILE
fi

echo "Restarting Puppet!"
service puppet restart
