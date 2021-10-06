# vfio-single-amdgpu-passthrough
This repo is a tutorial for single amd gpu passthrough to various qemu VMs.
After reading some great turorials by [Maagu Karuri](https://gitlab.com/Karuri/vfio) and [Joe Knockenhauer](https://github.com/joeknock90/Single-GPU-Passthrough) I wanted to try it myself, unfortunately there were no instructions for amd gpus, just warnings about the dreaded reset bug.

So, this will be my first attempt at contributing back to this community of enthusiasts and tinkers.

This description will be changed and beautified, but untill then, lets get to the improtant stuff.

Considering that you already seen the other tutroials and have an ideea about what goes on, i'll just show why it didn't work for me, and after that I'll show you the final working version of start.sh. Please keep in mind that, the gpu has already been added in the vm xml, and vfio has also been enabled, but that's it, no nomode
set or efifb:off was used.

```sh
#!/bin/bash
# Helpful to read output when debugging
set -x

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

# Stop your display manager
systemctl stop lightdm.service

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind



# Avoid a race condition by waiting a couple of seconds. This can be calibrated to be shorter or longer if required for your system
sleep 5

# Unload all Nvidia drivers
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r drm_kms_helper
modprobe -r nvidia
modprobe -r i2c_nvidia_gpu
modprobe -r drm

# Unbind the GPU from display driver
virsh nodedev-detach $VIRSH_GPU_VIDEO
virsh nodedev-detach $VIRSH_GPU_AUDIO


# Load VFIO kernel module
modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
```
DO NOT USE THIS FOR YOUR START.SH , use the start.sh uploaded by me!

The reason why it locks up, is because we are basically cutting the gpu short without letting the driver know that it will end, with NVidia it works because the driver knows how to reset itself, amd's doesn't

The working version will be attached as start.sh , but just to explain a bit, this is what I did, and the reason behind it.

First things first, after killing the display manager, we have to kill pulseAudio and pipewire, we get the process id for both of them using pgrep, and then we kill them.
We do this because our gpu is used by amdgpu(as a display adapter) and by snd_hda_intel(as an audio output for hdmi), this can be checked using the following command:

lspci -v:
```
09:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere [Radeon RX 470/480/570/570X/580/580X/590] (rev e7) (prog-if 00 [VGA controller])
        Subsystem: XFX Pine Group Inc. Radeon RX 580
        Flags: bus master, fast devsel, latency 0, IRQ 95, IOMMU group 23
        Memory at d0000000 (64-bit, prefetchable) [size=256M]
        Memory at e0000000 (64-bit, prefetchable) [size=2M]
        I/O ports at e000 [size=256]
        Kernel driver in use: amdgpu  <------- HERE WE CAN SEE THE MODULE\DRIVER
        Kernel modules: amdgpu  

09:00.1 Audio device: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere HDMI Audio [Radeon RX 470/480 / 570/580/590]
        Subsystem: XFX Pine Group Inc. Ellesmere HDMI Audio [Radeon RX 470/480 / 570/580/590]
        Flags: bus master, fast devsel, latency 0, IRQ 108, IOMMU group 23
        Memory at fce60000 (64-bit, non-prefetchable) [size=16K]
        Kernel driver in use: snd_hda_intel
        Kernel modules: snd_hda_intel   <----- HERE WE CAN SEE THE OTHER MODULE\DRIVER

```

Next we unbind the VTConsoles without unbinding the EFI-Framebuffer, because if we would do that , we would get a segmentation fault.
Instead, now that the display manager and pulseaudio are off ,we can unload all the modules(amdgpu and snd_hda_intel) that use the gpu(both the video and audio part)

After that is done, we now detach the gpu using virsh, and we load the vfio modules and thats it, if you added the gpu to you VM and you configured it to use q35 efi instead of bios, everything will work :D .
One last trick would be to always remove the monitor(spice or vnc) and vgpu of the vm(qxl or virtio), by doing so, you will see the bios/efi output as well as the final os on your passed gpu.

As of 27/1/2021 I have also added my stop.sh script, if my start.sh script(which I also updated today) work for you, the stop.sh should work as well.

Again, huge thanks to Maagu Karuri annd Joe Knockenhauer for there work and dedication.

#BONUS: [vendor-reset](https://github.com/gnif/vendor-reset) , this will allow you to always(or almost always) be able to have a clean release of the gpu when you stop a vm.
As far as I'm concerned, it works great for my card, some say it does not work for everyone, for me it does.
Some operating systems are almost guaranteed to do a clean shutdown, but others like macOS are not
And of course, by using vendor-reset, you can safely kill(virsh destroy) any stuck vm, without the risk of losing the usability of the card until a new reset. 
