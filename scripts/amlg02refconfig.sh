#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

# ***************
# Create fstab
# ******
echo "Creating \"fstab\""
echo "# Amlogic fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

echo "Installing additional packages"
apt-get update
apt-get -y install u-boot-tools liblircclient0 lirc mc abootimg fbset python-pip

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean

echo "Setting up platform-specific stuff:"
echo "- Platform init"
echo "#!/bin/sh -e
/etc/platform_init.sh &
exit 0" > /etc/rc.local

echo "- Enabling mpd-pause-btw-tracks service"
systemctl enable mpd-pause-btw-tracks

echo "- Masking alsa-store service"
systemctl mask alsa-store

echo "- VFD"
git clone https://github.com/patrickkfkan/tm1628mpd.git
cd tm1628mpd
pip install .
cd systemd
./install.sh
cd ../..
rm -rf tm1628mpd

echo "Adding custom modules overlayfs, squashfs and nls_cp437"
echo "overlayfs" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "nls_cp437" >> /etc/initramfs-tools/modules

#echo "Adding VFD module"
#echo "venus_vfd" >> /etc/initramfs-tools/modules

echo "Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

#On The Fly Patch
if [ "$PATCH" = "volumio" ]; then
echo "No Patch To Apply"
else
echo "Applying Patch ${PATCH}"
PATCHPATH=/${PATCH}
cd $PATCHPATH
#Check the existence of patch script
if [ -f "patch.sh" ]; then
sh patch.sh
else
echo "Cannot Find Patch File, aborting"
fi
cd /
rm -rf ${PATCH}
fi
rm /patch

#echo "Changing to 'modules=dep'"
#echo "(otherwise won't boot due to uInitrd 4MB limit)"
#sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

echo "Installing winbind here, since it freezes networking"
apt-get update
apt-get install -y winbind libnss-winbind

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

#First Boot operations
echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

echo "Creating uInitrd from 'volumio.initrd'"
mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd

echo "Creating aml_autoscript"
mkimage -A arm -O linux -T script -C none -d /boot/aml_autoscript.cmd /boot/aml_autoscript

echo "Removing unnecessary /boot files"
rm /boot/volumio.initrd
rm /boot/aml_autoscript.cmd
