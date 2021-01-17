#!/bin/bash
# Helpful to read output when debugging
set -x

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

# Stop your display manager. If youre on kde it ll be sddm.service. Gnome users should use killall gdm-x-session instead
systemctl stop sddm.service
pulse_pid=$(pgrep -u YOURUSERNAME pulseaudio)
pipewire_pid=$(pgrep -u YOURUSERNAME pipewire-media)
kill $pulse_pid
kill $pipewire_pid

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind
# Some machines might have more than 1 virtual console. Add a line for each corresponding VTConsole
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Unbind EFI-Framebuffer
#echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Avoid a race condition by waiting a couple of seconds. This can be calibrated to be shorter or longer if required for your system
sleep 8

# Unload all Radeon drivers

modprobe -r amdgpu
modprobe -r gpu_sched
modprobe -r ttm
modprobe -r drm_kms_helper
modprobe -r i2c_algo_bit
modprobe -r drm
modprobe -r snd_hda_intel

# Unbind the GPU from display driver
virsh nodedev-detach $VIRSH_GPU_VIDEO
virsh nodedev-detach $VIRSH_GPU_AUDIO
#virsh nodedev-detach $VIRSH_GPU_USB
#virsh nodedev-detach $VIRSH_GPU_SERIAL

# Load VFIO kernel module
modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
