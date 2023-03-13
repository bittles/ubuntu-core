#!/usr/bin/env bash
set -e

apt-get update
# Update tzdata noninteractive (otherwise our script is hung on user input later).
DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata
apt-get install -y vim wget net-tools locales bzip2 wmctrl software-properties-common mesa-utils 
apt-get clean -y

echo "generate locales für en_US.UTF-8"
locale-gen en_US.UTF-8

#update mesa to latest
add-apt-repository ppa:kisak/turtle
apt full-upgrade -y