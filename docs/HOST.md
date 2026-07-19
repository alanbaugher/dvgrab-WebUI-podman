# Host Operating System Configuration

This document describes every change made to the Ubuntu host operating system.

The goal is that a freshly installed Ubuntu machine can be converted into a
working Digital8 capture appliance by following this document.

---

# Platform

Tested on:

- Ubuntu 24.04 LTS
- Linux 6.17.x
- Rootless Podman
- Quadlet
- Texas Instruments IEEE-1394 PCI adapter
- Sony Digital8 camcorder

---

# Philosophy

The host operating system should remain as close to a stock Ubuntu installation
as practical.

All application software executes inside a rootless Podman container.

Only hardware support, storage, and container runtime are installed on the
host.

---

# Installed Packages

Required packages:

```bash
sudo apt install \
    podman \
    podman-docker \
    uidmap \
    dvgrab \
    ffmpeg \
    libraw1394-tools \
    curl
```

Useful diagnostics:

```bash
plugreport
testlibraw
dvgrab --version
ffprobe
```

---

# Rootless Podman

The appliance intentionally uses rootless Podman.

Advantages:

- no Docker daemon
- no host root privileges
- native systemd integration
- Quadlet support
- automatic startup after login

Verify:

```bash
podman info
```

---

# Quadlet

The application is started using a Quadlet container definition.

Location:

```text
~/.config/containers/systemd/dvgrab-webui.container
```

After modifying:

```bash
systemctl --user daemon-reload
systemctl --user restart dvgrab-webui.service
```

---

# FireWire Hardware

Verified controller:

Texas Instruments

```
104c:8024
TSB43AB23
```

Verify:

```bash
lspci -nn | grep -i firewire
```

Expected:

```
08:00.0 FireWire (IEEE 1394)
```

Kernel driver:

```
firewire_ohci
```

Verify:

```bash
lsmod | grep firewire
```

---

# FireWire Device Permissions

A custom udev rule grants access to FireWire devices.

Rule:

```
/etc/udev/rules.d/70-firewire-dv.rules
```

Contents:

```udev
SUBSYSTEM=="firewire", KERNEL=="fw[0-9]*", GROUP="firewire", MODE="0660"
```

Reload:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=firewire
```

Expected:

```text
crw-rw---- root firewire /dev/fw0
crw-rw---- root firewire /dev/fw1
```

---

# FireWire Group

Create if necessary:

```bash
sudo groupadd -f firewire
```

Add appliance user:

```bash
sudo usermod -aG firewire $USER
```

Log out and back in.

Verify:

```bash
id
```

---

# Rootless Podman Device Mapping

Inside the container the devices appear as:

```
nobody:nogroup
```

Example:

```
crw-rw---- nobody nogroup /dev/fw0
```

This is expected.

Rootless Podman uses user namespaces.

The underlying host permissions remain:

```
root:firewire
0660
```

---

# IOMMU

Kernel parameter:

```
iommu=pt
```

Current kernel command line:

```bash
cat /proc/cmdline
```

Expected:

```
iommu=pt
```

Purpose:

Enable IOMMU while using passthrough mappings for most devices.

Observed result:

Prior to enabling:

```
AMD-Vi:
IO_PAGE_FAULT
```

during long DV capture.

After enabling:

No page faults observed during testing.

Verification:

```bash
sudo dmesg | grep iommu
```

Expected:

```
Default domain type: Passthrough
```

---

# Storage

Capture destination:

```
/mnt/digital8/incoming
```

Mounted from Synology via NFS.

Container bind mount:

```
/captures
```

---

# Network

Application listens on:

```
5151/tcp
```

Host:

```
http://HOSTNAME:5151
```

---

# Verification Checklist

Verify FireWire:

```bash
lspci -nn | grep FireWire
```

Verify driver:

```bash
lsmod | grep firewire
```

Verify device nodes:

```bash
ls -l /dev/fw*
```

Verify user:

```bash
id
```

Verify camera:

```bash
plugreport
```

Verify raw1394:

```bash
testlibraw
```

Verify dvgrab:

```bash
dvgrab --version
```

Verify container:

```bash
systemctl --user status dvgrab-webui.service
```

Verify API:

```bash
curl http://127.0.0.1:5151/api/device
```

Expected:

```json
{
  "connected": true,
  "ready": true,
  "vendor": "Sony"
}
```

---

# NFS Notes

sudo apt install nfs-common

$ which mount.nfs
/usr/sbin/mount.nfs

$ cat /etc/fstab | grep nfs
192.168.X.YY:/volume1/Digital8  /mnt/digital8  nfs4  vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev,nofail  0  0

$ showmount -a 192.168.X.YY
All mount points on 192.168.X.YY:
192.168.X.ZZ:/volume1/Digital8

$ mount | grep digital8
192.168.X.YY:/volume1/Digital8 on /mnt/digital8 type nfs4 (rw,relatime,vers=4.1,rsize=131072,wsize=131072,namlen=255,hard,noresvport,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.X.ZZ,local_lock=none,addr=192.168.X.YY,_netdev)


<img width="4410" height="760" alt="image" src="https://github.com/user-attachments/assets/971390e7-1666-4431-80be-68e3a990504e" />  



---

# Notes

The container intentionally runs as UID 0 internally.

This is **not** host root.

The container itself is executed by rootless Podman.

Testing showed:

✓ UID 1000 inside container could access NFS storage.

✗ UID 1000 inside container could not reliably access FireWire character devices.

Reverting to internal UID 0 restored:

- camera detection
- AV/C transport control
- stable DV capture

This configuration is considered the production configuration for this appliance.

---

# Recovery

After reinstalling Ubuntu:

1. Install required packages.
2. Install Podman.
3. Create the firewire group.
4. Install the custom udev rule.
5. Add the appliance user to the firewire group.
6. Configure NFS mount.
7. Add `iommu=pt` to GRUB.
8. Reboot.
9. Install the dvgrab-WebUI project.
10. Run `./install.sh`.

A successful installation should require no manual changes beyond those documented in this file.
