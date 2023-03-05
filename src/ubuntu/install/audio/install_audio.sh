#!/usr/bin/env bash
### every exit != 0 fails the script
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
echo "Install Audio Requirements"
apt-get update
apt-get install -y curl git ffmpeg


mkdir -p /var/run/pulse

cd $STARTUPDIR
mkdir jsmpeg
wget -qO- https://kasmweb-build-artifacts.s3.amazonaws.com/kasm_websocket_relay/f173f72a9faa6239e43f2efcb48aabe8a984d443/kasm_websocket_relay_${DISTRO/kali/ubuntu}_${ARCH}_develop.f173f7.tar.gz | tar xz --strip 1 -C $STARTUPDIR/jsmpeg
chmod +x $STARTUPDIR/jsmpeg/kasm_audio_out-linux
