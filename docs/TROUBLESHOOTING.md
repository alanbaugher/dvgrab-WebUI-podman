# Troubleshooting

---

# Camera Not Detected

Verify

```bash
curl http://127.0.0.1:5151/api/device
```

Expected

```
connected: true
```

---

# FireWire Card

Verify

```bash
lspci -nn | grep FireWire
```

Expected

```
Texas Instruments
```

---

# FireWire Driver

Verify

```bash
lsmod | grep firewire
```

Expected

```
firewire_ohci
firewire_core
```

---

# Device Nodes

Verify

```bash
ls -l /dev/fw*
```

Expected

```
/dev/fw0
/dev/fw1
```

---

# Test dvgrab Directly

```bash
timeout --signal=INT 15s \
dvgrab \
--format raw \
test
```

Expected

```
Capture Started
Capture Stopped
```

---

# Verify IOMMU

```bash
cat /proc/cmdline
```

Expected

```
iommu=pt
```

---

# Check for AMD-Vi Errors

```bash
journalctl -k -b | grep AMD-Vi
```

Expected

Only boot-time initialization messages.

No

```
IO_PAGE_FAULT
```

during capture.

---

# Verify Container

```bash
systemctl --user status dvgrab-webui
```

---

# Verify WebUI

```bash
curl http://127.0.0.1:5151/api/status
```

---

# Verify Capture

```bash
ffprobe capture.dv
```

Expected

- DV Video
- PCM Audio
- Timecode

---

# Rebuild Image

```bash
FORCE=true ./build.sh
```

---

# Restart

```bash
systemctl --user restart dvgrab-webui.service
```

---

# Last Resort

A complete rebuild should require only:

```bash
git clone ...

./build.sh

./install.sh

./start.sh
```

The appliance was intentionally designed to be disposable and easily recreated.
