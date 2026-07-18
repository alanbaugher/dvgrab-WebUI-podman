# dvgrab-WebUI-podman

<img width="992" height="784" alt="image" src="https://github.com/user-attachments/assets/8f6dbd99-f624-4cee-af9a-c5f924b37eab" />  


A rootless Podman appliance for reliable Digital8 and MiniDV capture using **dvgrab** and a modern web interface.

This project packages the original **dvgrab-WebUI** application into a dedicated NUC appliance with a firewire card designed for long-term Digital8 and MiniDV preservation on Linux. It replaces the original Docker deployment with a fully rootless Podman + Quadlet + systemd architecture, adds deployment automation, validation tools, and extensive documentation for dedicated capture systems.

---

## Features

* Rootless Podman deployment
* Quadlet (systemd) integration
* Automatic service startup
* Gunicorn production WSGI server
* FireWire (IEEE-1394) device support
* Digital8 and MiniDV capture
* DV Type-2 and Raw DV capture formats
* Capture profiles
* Optional automatic tape rewind
* Automatic scene splitting
* NFS storage support (Synology tested)
* Validation and diagnostics
* Automated install, update, cleanup and uninstall scripts
* Designed for Ubuntu 24.04 LTS

---

# Project Relationship

This repository is **not** the original dvgrab-WebUI project.

Instead, it is an appliance-oriented fork that builds upon the excellent work of the original author while focusing on reliable, repeatable Linux deployment for dedicated capture hardware.

The intent is to provide a complete "capture appliance" that can be installed on a clean Ubuntu system and used for long-term Digital8 and MiniDV preservation.

---

# Upstream Projects

This project would not exist without two outstanding open-source projects.

## dvgrab-WebUI

Original WebUI project:

**henniiiing / dvgrab-WebUI**

https://github.com/henniiiing/dvgrab-WebUI

This repository began as a fork of that project.

The original project provides:

* Flask WebUI
* Browser-based capture control
* Device detection
* File management
* Web interface

This repository extends that work with:

* Rootless Podman support
* Quadlet deployment
* systemd integration
* Gunicorn
* Installation automation
* Validation framework
* Documentation
* Capture profiles
* Hardware appliance focus

Many thanks to the original author for making this project available.

---

## dvgrab

Actual tape capture is performed by **dvgrab**.

Original project:

**Dan Dennedy / dvgrab**

https://github.com/ddennedy/dvgrab

dvgrab is the mature and proven IEEE-1394 capture utility used by video archivists and Linux users for many years.

This repository does **not** replace dvgrab.

Instead, it provides a modern deployment and management environment around it.

Without dvgrab, this appliance would not exist.

Special thanks to Dan Dennedy and all contributors to the dvgrab project.

---

# Architecture

```
Sony Digital8 / MiniDV Camera
             │
      IEEE-1394 (FireWire)
             │
     Texas Instruments OHCI
             │
        Linux FireWire Stack
             │
           dvgrab
             │
      Flask / Gunicorn
             │
      Rootless Podman
             │
   Quadlet / systemd User Service
             │
      NFS / Local Storage
             │
        Captured DV Files
```

---

# Why Podman?

The original project targeted Docker.

This repository standardizes on:

* Rootless Podman
* Quadlet
* systemd user services

Benefits include:

* No Docker daemon
* No root-owned containers
* Automatic restart
* Native systemd integration
* Better long-term appliance deployment

---

# Why Gunicorn?

The original application uses Flask's development server.

This repository replaces it with Gunicorn while intentionally keeping:

* one worker
* shared in-memory capture state

This avoids multiple dvgrab instances attempting to control the same FireWire device.

---

# Tested Hardware


<img width="1998" height="1125" alt="image" src="https://github.com/user-attachments/assets/61be098b-79f4-47e3-8160-c6c4b57cdd4b" />  


Validated with:

* Sony DCR-TRV120 Digital8 camcorder
* Texas Instruments TSB43AB23 IEEE-1394 controller
* Ubuntu 24.04 LTS
* Rootless Podman
* Quadlet
* Gunicorn
* Synology NFS storage

---

# Installation

Clone the repository.

```bash
git clone <repository>
cd dvgrab-WebUI-podman
```

Install the appliance.

```bash
./install.sh
```

Start the service.

```bash
./start.sh
```

Verify installation.

```bash
./validate.sh
```

Display appliance status.

```bash
./status.sh
```

---

# Documentation

Additional documentation is located in the **docs/** directory.

* DESIGN.md
* HARDWARE.md
* HISTORY.md
* HOST.md
* NOTICE.md
* REFACTOR-V2.md
* TROUBLESHOOTING.md

---

# Project Goals

The primary goals of this project are:

* Long-term Digital8 preservation
* Reliable MiniDV capture
* Simple deployment
* Minimal maintenance
* Rootless operation
* Dedicated capture appliance
* Easily rebuilt from a clean Ubuntu installation

---

# License

This repository contains original work as well as modifications based upon upstream open-source projects.

Please see the repository LICENSE file for licensing information.

The original projects retain their respective copyrights and licenses.

---

# Acknowledgements

Many thanks to the original authors and contributors:

* **henniiiing** for dvgrab-WebUI
* **Dan Dennedy** for dvgrab
* The Linux FireWire maintainers
* The Podman and Quadlet developers
* The open-source community for continuing to preserve access to Digital8 and MiniDV media

Their work made this project possible.

