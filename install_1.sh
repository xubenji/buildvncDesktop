sudo apt upgrade -y
sudo apt install --no-install-recommends \
  xserver-xorg-core xserver-xorg-video-all xserver-xorg-input-all \
  xinit x11-xserver-utils -y
sudo apt install --no-install-recommends \
  lxde-core lxsession lxsession-logout lxpanel lxappearance lxpolkit openbox \
  -y
sudo apt install --no-install-recommends lightdm lightdm-gtk-greeter -y
sudo apt purge gdm3 gnome-shell -y
sudo apt autoremove --purge -y
sudo reboot

