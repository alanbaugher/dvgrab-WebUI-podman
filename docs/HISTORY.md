2026-07-15

Discovered Synology NFS root squash issue.

Resolved by running rootless Podman while keeping
container UID 0.

Reason:

FireWire device access failed under UID 1000.

#ls -l /dev/fw0 /dev/fw1
#crw-rw----  1 root firewire 239, 0 Jul 16 13:21 /dev/fw0
#crw-rw----+ 1 root firewire 239, 1 Jul 16 13:21 /dev/fw1

#podman exec dvgrab-webui ls -l /dev/fw0 /dev/fw1
#crw-rw----  1 nobody nogroup 239, 0 Jul 16 18:21 /dev/fw0
#crw-rw----+ 1 nobody nogroup 239, 1 Jul 16 18:21 /dev/fw1



---

2026-07-16

Discovered AMD-Vi page faults during sustained DMA.

Kernel: 6.17

Resolved with: iommu=pt

#cat /proc/cmdline
#BOOT_IMAGE=/boot/vmlinuz-6.17.0-40-generic root=UUID=ce222770-0285-4bc9-96b8-602a71f0e00e ro quiet splash iommu=pt vt.handoff=7


FireWire: TSB43AB23

#$ lspci -nn | grep -i firewire
#08:00.0 FireWire (IEEE 1394) [0c00]: Texas Instruments TSB43AB23 IEEE-1394a-2000 Controller (PHY/Link) [104c:8024]



