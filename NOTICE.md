# NOTICE

## dvgrab-WebUI-podman


This repository contains original work together with modifications,
enhancements, packaging, and deployment improvements built upon existing
open-source software.

---

# Purpose

This repository provides a dedicated Digital8 / MiniDV capture
appliance using:

- Rootless Podman
- Quadlet
- systemd
- Gunicorn
- dvgrab
- Flask WebUI

The goal is reliable long-term Digital8 and MiniDV preservation on Linux.

---

# Upstream Projects

This repository incorporates ideas and source code from the following
open-source projects.

## dvgrab-WebUI

Original project:

    https://github.com/henniiiing/dvgrab-WebUI

Copyright belongs to the original author(s).

The original project provides the browser-based Flask interface used for
controlling dvgrab.

This repository began as a fork of that project and substantially extends it
for appliance deployment.

---

## dvgrab

Original project:

    https://github.com/ddennedy/dvgrab

Copyright belongs to the original author(s).

dvgrab is the capture engine responsible for transferring Digital8 and MiniDV
video over IEEE-1394 (FireWire).

This repository does not replace or reimplement dvgrab.

Instead, it packages and manages dvgrab for dedicated capture appliances.

---

# Major Additions In This Repository

The following components are original work developed specifically for
dvgrab-WebUI-podman.

## Deployment

- Rootless Podman deployment
- Quadlet service generation
- systemd user services
- Automated installation
- Automated updates
- Automated uninstall
- Validation framework

---

## Container

- Production Dockerfile [Avoid dev message]
- Gunicorn deployment
- OCI image improvements
- Signal handling using tini
- Health check documentation
- Rootless container support

---

## Appliance

- Dedicated capture appliance architecture
- NFS storage integration
- FireWire host configuration
- AMD IOMMU documentation
- Hardware validation
- Capture profiles
- Automatic rewind support
- Maintenance scripts

---

## Documentation

Repository documentation including:

- README
- HOST.md
- DESIGN.md
- HARDWARE.md
- TROUBLESHOOTING.md
- HISTORY.md

was written specifically for this project.

---

# What This Repository Is Not

This repository is **not** the official dvgrab-WebUI repository.

It is an independently maintained appliance-oriented fork intended for
dedicated Linux capture systems.

Bug reports relating to appliance deployment should be directed to this
repository.

Bug reports relating to the original WebUI should be directed to the upstream
project.

Bug reports relating to dvgrab itself should be directed to the dvgrab project.

---

# Attribution

Many thanks to the original authors whose work made this project possible.

## dvgrab-WebUI

Original author:

    henniiiing

Repository:

    https://github.com/henniiiing/dvgrab-WebUI

---

## dvgrab

Original author:

    Dan Dennedy

Repository:

    https://github.com/ddennedy/dvgrab

---

# Licensing

The original upstream projects remain licensed under their respective licenses.

Nothing in this repository changes, replaces, or supersedes those licenses.

New code and documentation added by this repository are licensed under the
LICENSE file distributed with this repository unless otherwise noted.

---

# Philosophy

This repository intentionally focuses on reliability rather than adding large
numbers of features.

Every significant design decision was made to improve one or more of the
following:

- Capture reliability
- Ease of deployment
- Long-term maintainability
- Appliance-style operation
- Digital8 and MiniDV preservation

The objective is a system that can be installed on a clean Ubuntu machine,
connected to a Digital8 or MiniDV camcorder, and reliably capture tapes for
many years with minimal maintenance.
