# Hardware Notes

This document describes the hardware configuration validated for this project.

---

# Validated Platform

Motherboard

    ASUS (Ryzen platform)

CPU

    AMD Ryzen

Operating System

    Ubuntu Server 24.04.4 LTS

Kernel

    Linux 6.17.x

Container Runtime

    Podman (Rootless)

Storage

    Synology NAS
    NFSv4.1

---

# FireWire Controller

Texas Instruments

TSB43AB23

PCI ID

```
104c:8024
```

Verified with

```bash
lspci -nn | grep FireWire
```

Expected

```
08:00.0 FireWire (IEEE 1394)
Texas Instruments TSB43AB23
```

---

# Tested Camera

Sony

DCR-TRV120

Verified features

- AV/C transport
- Device detection
- Continuous DV capture
- Timecode
- Audio
- Video

---

# AMD Ryzen IOMMU Notes

During development the following messages were observed:

```
AMD-Vi:
IO_PAGE_FAULT
```

These occurred continuously during DV capture.

Although captures succeeded, the kernel generated large numbers of DMA page fault reports.

Changing the Linux kernel boot parameter to

```
iommu=pt
```

eliminated these page faults.

The AMD IOMMU remains enabled.

Interrupt remapping remains enabled.

Only DMA mapping changes to passthrough mode.

Verify:

```bash
cat /proc/cmdline
```

Expected

```
iommu=pt
```

Verify

```bash
sudo dmesg | grep "Default domain"
```

Expected

```
iommu: Default domain type: Passthrough
```

---

# FireWire Device

Expected

```
/dev/fw0
/dev/fw1
```

Verify

```bash
ls -l /dev/fw*
```

---

# Capture Verification

A successful capture should produce

```
Found AV/C device

Capture Started

Capture Stopped
```

No AMD-Vi IO_PAGE_FAULT messages should appear during capture.

---

# Notes

This appliance has been validated for multi-hour Digital8 capture using this hardware configuration.
