# Desktop with customizations to fit in a CD (package removals, etc.)
# Maintained by the Fedora Desktop SIG:
# http://fedoraproject.org/wiki/SIGs/Desktop
# mailto:desktop@lists.fedoraproject.org

%include fedora-live-base.ks




# System language
lang cs_CZ.UTF-8
keyboard --xlayouts='cz'
# System services
services --enabled="chronyd,brltty,festival"
# System timezone
timezone Europe/Prague --isUtc

network --nameserver=8.8.8.8 --bootproto=dhcp --device=link --activate

part / --size 8500

%packages
@mate
compiz
compiz-plugins-main
compiz-plugins-extra
compiz-manager
compizconfig-python
compiz-plugins-experimental
libcompizconfig
compiz-plugins-main
ccsm
simple-ccsm
emerald-themes
emerald
fusion-icon
@networkmanager-submodules

# some apps from mate-applications
caja-actions
mate-disk-usage-analyzer

# blacklist applications which breaks mate-desktop
-audacious

# office
@libreoffice

# dsl tools
rp-pppoe

# FIXME; apparently the glibc maintainers dislike this, but it got put into the
# desktop image at some point.  We won't touch this one for now.
nss-mdns

# Drop things for size
-@3d-printing
-fedora-icon-theme
-gnome-icon-theme
-gnome-icon-theme-symbolic
-gnome-software
-gnome-user-docs

#-@mate-applications
-mate-icon-theme-faenza

# Help and art can be big, too
-gnome-user-docs
-evolution-help

#customizations for Agora
#removing inaccessible packages
-filezilla
-exaile

#additional software for Agora
gimagereader-qt
pidgin
purple-facebook
purple-skypeweb
pidgin-skypeweb
xsane
chromium
mate-menu
#hardware support
@hardware-support
gutenprint-cups
cups-bjnp
cups-filters
foomatic-db
foomatic-db-ppds
splix
hplip
xorg-x11-drv-nouveau
libsane-hpaio
xorg-x11-server-Xvfb
xorg-x11-drv-dummy
#more software
fuse-exfat
audacity
soundconverter
tesseract-langpack-ces
tesseract-langpack-slk
ifuse
git
curl
vlc
sed
java-atk-wrapper
qt-at-spi
wget
jmtpfs
exfat-utils
nano
speech-dispatcher-utils
soundconverter
tmux
unrar
timidity++
#lios dependencies
python3-sane
#cuneiform
python3-enchant
aspell-en
aspell-cs
#festival
festival-freebsoft-utils
speech-dispatcher-festival
festvox-czech-dita
festvox-czech-machac
festvox-czech-krb
festvox-czech-ph 
pulseaudio-utils
#boot
grub2-pc
grub2-pc-modules
grub2-efi-x64
grub2-efi-x64-modules
shim-x64
#display manager
-slick-greeter
-slick-greeter-mate
lightdm-gtk-greeter
lightdm-gtk-greeter-settings
#ocrdesktop dependencies
g++
python3-devel
tesseract-devel
python3-tesserwrap
%end

%post
cat >> /etc/rc.d/init.d/livesys << EOF


# make the installer show up
if [ -f /usr/share/applications/liveinst.desktop ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
fi
mkdir /home/liveuser/Desktop
cp /usr/share/applications/liveinst.desktop /home/liveuser/Desktop

# and mark it as executable
chmod +x /home/liveuser/Desktop/liveinst.desktop

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up lightdm autologin
sed -i 's/^#autologin-user=.*/autologin-user=liveuser/' /etc/lightdm/lightdm.conf
sed -i 's/^#autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
#sed -i 's/^#show-language-selector=.*/show-language-selector=true/' /etc/lightdm/lightdm-gtk-greeter.conf

# set MATE as default session, otherwise login will fail
sed -i 's/^#user-session=.*/user-session=mate/' /etc/lightdm/lightdm.conf

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# no updater applet in live environment
rm -f /etc/xdg/autostart/org.mageia.dnfdragora-updater.desktop

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/

# set x11 keymap manually, for some reason the keyboard kickstart command does not work
localectl set-x11-keymap cz

EOF

# configure temporary dns
#cat >> /etc/resolv.conf << EOM
#nameserver 8.8.8.8
#nameserver 8.8.4.4
#EOM


#rpm fusion keys
echo "== RPM Fusion Free: Base section =="
echo "Importing RPM Fusion keys"
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-*-primary
echo "Importing RPM Fusion keys"
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-*-primary

#installing lios
cd /opt/
git clone https://github.com/Nalin-x-Linux/Lios.git
cd Lios
python3 setup.py install
cd ..
rm -rf Lios

#installing ocrdesktop
git clone https://github.com/chrys87/ocrdesktop.git /opt/ocrdesktop
chmod -R 755 /opt/ocrdesktop
ln -s /opt/ocrdesktop/ocrdesktop /usr/local/bin/ocrdesktop
# create script to toggle monitor
mkdir -p /usr/local/bin
cat > /usr/local/bin/monitor-toggle <<EOM
#!/bin/sh
output=$(xrandr | grep ' connected ' | awk '{print $1}' | head -1)
screenSize=$(xrandr | awk 'BEGIN {foundOutput=0}
    / '$output' / {foundOutput=1}
    /\*\+/ {print $1}
    /^[^ ]/ {if(foundOutput) exit 0}')
if [ "$screenSize" != "" ]; then
    xrandr --output $output --fb $screenSize --off
	spd-say 'monitor off'
else
    xrandr --output $output --auto
    spd-say 'Monitor on'
fi

EOM
chmod 755 /usr/local/bin/monitor-toggle
echo "Preparing accessibility override..."
cat > /etc/dconf/db/local.d/01-accessibility <<- EOM
# Be nice to the users and pre-enable screen reading if they decide to install Gnome.
[org/gnome/desktop/a11y/applications]
screen-reader-enabled=true

[org/mate/desktop/applications/at/visual]
startup=true

[org/mate/desktop/interface]
accessibility=true

#enabling sound theme
[org/mate/desktop/sound]
theme-name='freedesktop'
event-sounds=true

EOM
echo "Preparing Mate panel configuration override..."

echo "Updating dconf databases..."
dconf update
# enabling accessibility
cat > /etc/profile.d/qtaccessibility.sh <<EOM
#enable general accessibility according to https://www.freedesktop.org/wiki/Accessibility/AT-SPI2/
export GTK_MODULES=gail:atk-bridge
export OOO_FORCE_DESKTOP=gnome
export GNOME_ACCESSIBILITY=1
# enables QT5 accessibility system-vide
export QT_ACCESSIBILITY=1
export QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1
EOM

# install linux-a11y sound theme
git clone https://github.com/coffeeking/linux-a11y-sound-theme.git
cp -r linux-a11y-sound-theme/linux-a11y /usr/share/sounds/

#apply Fegora customizations
git clone https://github.com/vojtapolasek/Fegora.git
cd Fegora/downloads
mkdir -p /etc/skel/.local/share/orca
cp -r orca/* /etc/skel/.local/share/orca/
mkdir -p /etc/skel/.config
cp mimeapps.list /etc/skel/.config/
cp klavesove_zkratky.txt /etc/skel/
cp handout.html /etc/skel/
cp .tmux.conf /etc/skel/
mkdir -p /etc/skel/.mozilla/firefox
cp -r firefox/* /etc/skel/.mozilla/firefox/
cd /opt/
rm -rf Fegora
#configure festival
sed 's/#AddModule "festival"                 "sd_festival"  "festival\.conf"/AddModule "festival"                 "sd_festival"  "festival\.conf"/' /etc/speech-dispatcher/speechd.conf
echo "(set! voice_default 'voice_czech_dita)" > /etc/skel/.festivalrc

mkdir /etc/systemd/system/festival.service.d
cat > /etc/systemd/system/festival.service.d/override.conf <<EOM
[Service]
WorkingDirectory=/usr/share/festival/lib

EOM
#configure speech dispatcher
sed -i 's/#AddModule "espeak-ng"                "sd_espeak-ng" "espeak-ng.conf"/AddModule "espeak-ng"                "sd_espeak-ng" "espeak-ng.conf"/' /etc/speech-dispatcher/speechd.conf
sed -i 's/#AddModule "festival"                 "sd_festival"  "festival.conf"/AddModule "festival"                 "sd_festival"  "festival.conf"/' /etc/speech-dispatcher/speechd.conf
# prevent long delay when shutting down
echo "DefaultTimeoutStopSec=10s" >> /etc/systemd/system.conf
#setup lightdm
# create a wrapper script which makes sure that sound is unmuted and at 50% on login screen
cat > /usr/local/bin/orca-login-wrapper <<EOM
#!/bin/bash

amixer -c 0 set Master playback 50% unmute
/usr/bin/orca &

EOM
chmod 755 /usr/local/bin/orca-login-wrapper
cat >> /etc/lightdm/lightdm-gtk-greeter.conf <<EOM
[greeter]
background = /usr/share/backgrounds/default.png
reader = /usr/local/bin/orca-login-wrapper
a11y-states = +reader

EOM

#clear temporary dns settings
#echo "" > /etc/resolv.conf
%end
