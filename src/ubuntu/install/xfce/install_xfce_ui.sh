#!/usr/bin/env bash
### every exit != 0 fails the script
set -e

get_rid_of_policykit_error() {
  rm -f /etc/xdg/autostart/xfce-polkit.desktop
}

disable_epel_nss_wrapper_that_breaks_firefox() {
  yum-config-manager --setopt=epel.exclude=nss_wrapper --save
}

config_xinit_disable_screensaver() {
  mkdir -p /etc/X11/xinit/xinitrc.d/
  cat >/etc/X11/xinit/xinitrc.d/disable_screensaver.sh <<EOL
#!/bin/sh
set -x
xset -dpms
xset s off
xset q
EOL
chmod +x /etc/X11/xinit/xinitrc.d/disable_screensaver.sh
}

replace_default_xinit() {
  mkdir -p /etc/X11/xinit
  cat >/etc/X11/xinit/xinitrc <<EOL
#!/bin/sh
for file in /etc/X11/xinit/xinitrc.d/* ; do
        . \$file
done
. /etc/X11/Xsession
EOL

chmod +x /etc/X11/xinit/xinitrc
}

replace_default_99x11_common_start() {
  if [ -f /etc/X11/Xsession.d/99x11-common_start ] ; then
    cat >/etc/X11/Xsession.d/99x11-common_start <<EOL
# This file is sourced by Xsession(5), not executed.
# exec $STARTUP
EOL
  fi
}

echo "Install Xfce4 UI components"
if [[ "${DISTRO}" != @(centos|oracle7|oracle8|opensuse) ]]; then
  apt-get update
fi

apt-get purge -y pm-utils xscreensaver*
apt-get clean -y

replace_default_xinit
config_xinit_disable_screensaver
if [ "${START_XFCE4}" == "1" ] ; then
  replace_default_99x11_common_start
fi

# Override default login script so users cant log themselves out of the desktop dession
cat >/usr/bin/xfce4-session-logout <<EOL
#!/usr/bin/env bash
notify-send "Logout" "Please logout or destroy this desktop using the Kasm Control Panel" -i /usr/share/icons/ubuntu-mono-dark/actions/22/system-shutdown-panel-restart.svg
EOL

# Add a script for launching Thunar with libnss wrapper.
# This is called by ~.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
cat >/usr/bin/execThunar.sh <<EOL
#!/bin/sh
. $STARTUPDIR/generate_container_user
/usr/bin/Thunar --daemon
EOL
chmod +x /usr/bin/execThunar.sh

cat >/usr/bin/desktop_ready <<EOL
#!/usr/bin/env bash
until pids=\$(pidof xfce4-session); do sleep .5; done
EOL
chmod +x /usr/bin/desktop_ready

# Change the default behavior of the delete key which is to move to trash. This will now prompt the user to permanently
# delete the file instead of moving it to trash
mkdir -p /etc/xdg/Thunar/
cat >>/etc/xdg/Thunar/accels.scm<<EOL
(gtk_accel_path "<Actions>/ThunarStandardView/delete" "Delete")
(gtk_accel_path "<Actions>/ThunarLauncher/delete" "Delete")
(gtk_accel_path "<Actions>/ThunarLauncher/trash-delete-2" "")
(gtk_accel_path "<Actions>/ThunarLauncher/trash-delete" "")
EOL
