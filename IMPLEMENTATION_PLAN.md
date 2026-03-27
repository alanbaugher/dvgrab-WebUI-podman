# dvgrab-web 90s Retro-Tech Redesign

## Overview

Transform the frontend from modern dark theme to a 90s camcorder/VCR aesthetic with device detection for "NO SIGNAL" / "CONNECTED" states.

---

## Backend Changes

### File: `app.py`

#### 1. Add Camcorder Detection Function

Add this function after the imports and before the routes:

```python
def detect_camcorder():
    """Check if a DV camcorder is connected via FireWire/IEEE 1394"""
    devices_path = "/sys/bus/firewire/devices/"
    if not os.path.exists(devices_path):
        return False
    
    try:
        for device in os.listdir(devices_path):
            is_local_path = os.path.join(devices_path, device, "is_local")
            if os.path.exists(is_local_path):
                with open(is_local_path) as f:
                    # is_local: 0 = external device (camcorder), 1 = local controller
                    if f.read().strip() == "0":
                        return True
    except (IOError, OSError):
        pass
    return False
```

#### 2. Add Device Status API Endpoint

Add this route after the existing routes:

```python
@app.route("/api/device")
def device_status():
    """Return whether a DV camcorder is connected"""
    return jsonify({"connected": detect_camcorder()})
```

---

## Frontend Changes

### File: `templates/index.html`

Complete rewrite of the `<style>` section and minor JavaScript updates.

---

### Color Palette

| Element | Color | Hex |
|---------|-------|-----|
| Background | Dark navy | `#0a1628` |
| Card/Panel background | Darker navy | `#0d1a2d` |
| Primary accent (amber) | LCD amber | `#ff9f1c` |
| Secondary accent | Silver/chrome | `#c0c0c0` |
| REC indicator | Blinking red | `#ff0040` |
| Connected indicator | LCD green | `#39ff14` |
| No signal | Dim gray | `#666666` |
| Text | Off-white | `#e0e0e0` |
| LCD panel background | Very dark | `#050a12` |

---

### CSS Styles (Complete Replacement)

#### Base Styles & Scanlines

```css
* { box-sizing: border-box; margin: 0; padding: 0; }

body {
    font-family: "Courier New", "Lucida Console", monospace;
    background: #0a1628;
    color: #e0e0e0;
    min-height: 100vh;
    padding: 20px;
    position: relative;
}

/* Static CRT scanline overlay */
body::before {
    content: "";
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: repeating-linear-gradient(
        0deg,
        transparent,
        transparent 2px,
        rgba(0, 0, 0, 0.15) 2px,
        rgba(0, 0, 0, 0.15) 4px
    );
    pointer-events: none;
    z-index: 1000;
}
```

#### Container

```css
.container {
    max-width: 900px;
    margin: 0 auto;
    border: 3px outset #2a4a6a;
    background: #0d1a2d;
    padding: 25px;
    box-shadow: 
        inset 1px 1px 0 rgba(255,255,255,0.1),
        inset -1px -1px 0 rgba(0,0,0,0.3),
        5px 5px 15px rgba(0,0,0,0.5);
}
```

#### VCR-Style Title

```css
h1 {
    text-align: center;
    margin-bottom: 25px;
    font-size: 2.2em;
    font-weight: bold;
    color: #ff9f1c;
    text-shadow: 
        0 0 10px #ff9f1c,
        0 0 20px #ff9f1c,
        0 0 30px #ff9f1c;
    letter-spacing: 8px;
    text-transform: uppercase;
    font-family: "Courier New", monospace;
    border-bottom: 2px groove #2a4a6a;
    padding-bottom: 15px;
}
```

#### LCD Status Panel

```css
.status-lcd {
    background: #050a12;
    border: 3px inset #1a2a3a;
    padding: 15px 20px;
    margin-bottom: 20px;
    font-family: "Courier New", monospace;
    font-size: 1.1em;
    box-shadow: inset 2px 2px 8px rgba(0,0,0,0.8);
    min-height: 50px;
    display: flex;
    align-items: center;
    gap: 15px;
}

.status-lcd .status-text {
    flex: 1;
}

/* NO SIGNAL state */
.status-lcd.no-signal {
    color: #666666;
    text-shadow: none;
}

.status-lcd.no-signal .static-bars {
    display: inline-block;
    width: 100%;
    height: 4px;
    background: repeating-linear-gradient(
        90deg,
        #333 0px,
        #333 2px,
        #222 2px,
        #222 4px
    );
    animation: static-flicker 0.1s infinite;
}

@keyframes static-flicker {
    0%, 100% { opacity: 0.6; }
    50% { opacity: 0.4; }
}

/* CONNECTED state */
.status-lcd.connected {
    color: #39ff14;
    text-shadow: 0 0 8px #39ff14;
}

/* RECORDING state */
.status-lcd.recording {
    color: #ff9f1c;
    text-shadow: 0 0 8px #ff9f1c;
}

.rec-indicator {
    color: #ff0040;
    font-weight: bold;
    animation: rec-blink 1s ease-in-out infinite;
}

@keyframes rec-blink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.2; }
}
```

#### Card Panels (3D Beveled)

```css
.card {
    background: #12202e;
    border: 2px outset #2a4a6a;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 
        inset 1px 1px 0 rgba(255,255,255,0.05),
        inset -1px -1px 0 rgba(0,0,0,0.2);
}

.card h2 {
    margin-bottom: 15px;
    color: #ff9f1c;
    font-size: 1.1em;
    text-transform: uppercase;
    letter-spacing: 2px;
    border-bottom: 1px groove #2a4a6a;
    padding-bottom: 8px;
}
```

#### Form Inputs (Sunken/Inset)

```css
.form-row {
    display: flex;
    gap: 15px;
    flex-wrap: wrap;
    margin-bottom: 15px;
}

.form-group {
    flex: 1;
    min-width: 150px;
}

.form-group label {
    display: block;
    margin-bottom: 6px;
    color: #ff9f1c;
    font-size: 0.85em;
    text-transform: uppercase;
    letter-spacing: 1px;
}

input, select {
    width: 100%;
    padding: 10px 12px;
    border: 2px inset #1a2a3a;
    border-radius: 0;
    background: #0a1520;
    color: #39ff14;
    font-family: "Courier New", monospace;
    font-size: 1em;
    box-shadow: inset 2px 2px 5px rgba(0,0,0,0.5);
}

input:focus, select:focus {
    outline: none;
    border-color: #ff9f1c;
    box-shadow: inset 2px 2px 5px rgba(0,0,0,0.5), 0 0 5px rgba(255,159,28,0.3);
}

input::placeholder {
    color: #4a5a6a;
}

select {
    cursor: pointer;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23ff9f1c' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 10px center;
    padding-right: 30px;
}

select option {
    background: #0d1a2d;
    color: #e0e0e0;
}
```

#### Checkbox Styling

```css
.checkbox-group {
    display: flex;
    align-items: center;
    gap: 10px;
}

.checkbox-group input[type="checkbox"] {
    width: 18px;
    height: 18px;
    appearance: none;
    border: 2px inset #1a2a3a;
    background: #0a1520;
    cursor: pointer;
    box-shadow: inset 1px 1px 3px rgba(0,0,0,0.5);
}

.checkbox-group input[type="checkbox"]:checked {
    background: #39ff14;
    box-shadow: inset 1px 1px 3px rgba(0,0,0,0.3), 0 0 5px #39ff14;
}

.checkbox-group label {
    margin: 0 !important;
    border: none !important;
    padding: 0 !important;
}
```

#### 3D Beveled Buttons

```css
.btn {
    padding: 12px 24px;
    border: 2px outset;
    border-radius: 0;
    cursor: pointer;
    font-family: "Courier New", monospace;
    font-size: 1em;
    font-weight: bold;
    text-transform: uppercase;
    letter-spacing: 1px;
    transition: all 0.1s;
}

.btn:active {
    border-style: inset;
    transform: translate(1px, 1px);
}

.btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
    border-style: outset;
    transform: none;
}

/* Start button - green */
.btn-start {
    background: linear-gradient(180deg, #2ecc71 0%, #27ae60 50%, #1e8449 100%);
    border-color: #2ecc71 #1e8449 #1e8449 #2ecc71;
    color: #000;
    text-shadow: 0 1px 0 rgba(255,255,255,0.3);
}

.btn-start:hover:not(:disabled) {
    background: linear-gradient(180deg, #58d68d 0%, #2ecc71 50%, #27ae60 100%);
}

.btn-start:active:not(:disabled) {
    background: linear-gradient(180deg, #1e8449 0%, #27ae60 50%, #2ecc71 100%);
}

/* Stop button - red */
.btn-stop {
    background: linear-gradient(180deg, #e74c3c 0%, #c0392b 50%, #922b21 100%);
    border-color: #e74c3c #922b21 #922b21 #e74c3c;
    color: #fff;
    text-shadow: 0 1px 0 rgba(0,0,0,0.3);
}

.btn-stop:hover:not(:disabled) {
    background: linear-gradient(180deg, #ec7063 0%, #e74c3c 50%, #c0392b 100%);
}

.btn-stop:active:not(:disabled) {
    background: linear-gradient(180deg, #922b21 0%, #c0392b 50%, #e74c3c 100%);
}

/* Small action buttons - chrome/silver */
.btn-download, .btn-delete {
    padding: 6px 12px;
    font-size: 0.8em;
    background: linear-gradient(180deg, #d4d4d4 0%, #a0a0a0 50%, #808080 100%);
    border-color: #d4d4d4 #606060 #606060 #d4d4d4;
    color: #000;
}

.btn-download:hover, .btn-delete:hover {
    background: linear-gradient(180deg, #e8e8e8 0%, #b8b8b8 50%, #909090 100%);
}

.btn-download:active, .btn-delete:active {
    background: linear-gradient(180deg, #808080 0%, #a0a0a0 50%, #d4d4d4 100%);
}
```

#### File Table

```css
table {
    width: 100%;
    border-collapse: collapse;
    border: 2px inset #1a2a3a;
}

th, td {
    padding: 12px;
    text-align: left;
    border: 1px groove #2a4a6a;
}

th {
    background: #0a1520;
    color: #ff9f1c;
    text-transform: uppercase;
    font-size: 0.85em;
    letter-spacing: 1px;
}

tr:nth-child(odd) {
    background: #0d1a2d;
}

tr:nth-child(even) {
    background: #12202e;
}

tr:hover {
    background: #1a2a3d;
}

.actions {
    display: flex;
    gap: 8px;
}

.empty {
    text-align: center;
    color: #4a5a6a;
    padding: 30px;
    font-style: italic;
}
```

#### Responsive

```css
@media (max-width: 600px) {
    .form-row {
        flex-direction: column;
    }
    
    h1 {
        font-size: 1.5em;
        letter-spacing: 4px;
    }
    
    .btn {
        padding: 10px 16px;
        font-size: 0.9em;
    }
}
```

---

### HTML Structure Updates

#### Status LCD Panel

Replace the current status div:

```html
<div id="status-lcd" class="status-lcd no-signal">
    <span class="status-text">NO SIGNAL</span>
    <span class="static-bars"></span>
</div>
```

#### Button Container

Wrap buttons in a div for spacing:

```html
<div class="form-row">
    <button id="btn-start" class="btn btn-start" onclick="startCapture()">Start Capture</button>
    <button id="btn-stop" class="btn btn-stop" onclick="stopCapture()" disabled>Stop Capture</button>
</div>
```

---

### JavaScript Updates

#### Add Device Detection

Add new function and modify `updateStatus()`:

```javascript
let deviceConnected = false;

function updateDeviceStatus() {
    fetch('/api/device')
        .then(r => r.json())
        .then(data => {
            deviceConnected = data.connected;
            updateStatusDisplay();
        });
}

function updateStatusDisplay() {
    fetch('/api/status')
        .then(r => r.json())
        .then(data => {
            const lcd = document.getElementById('status-lcd');
            const btnStart = document.getElementById('btn-start');
            const btnStop = document.getElementById('btn-stop');
            
            // Clear all state classes
            lcd.classList.remove('no-signal', 'connected', 'recording');
            
            if (data.running) {
                // Recording state
                lcd.classList.add('recording');
                lcd.innerHTML = `
                    <span class="rec-indicator">● REC</span>
                    <span class="status-text">${data.filename} (PID: ${data.pid})</span>
                `;
                btnStart.disabled = true;
                btnStop.disabled = false;
            } else if (deviceConnected) {
                // Connected but not recording
                lcd.classList.add('connected');
                lcd.innerHTML = '<span class="status-text">► CONNECTED</span>';
                btnStart.disabled = false;
                btnStop.disabled = true;
            } else {
                // No device
                lcd.classList.add('no-signal');
                lcd.innerHTML = `
                    <span class="status-text">NO SIGNAL</span>
                    <span class="static-bars"></span>
                `;
                btnStart.disabled = true;
                btnStop.disabled = true;
            }
        });
}

// Update interval
setInterval(() => { 
    updateDeviceStatus(); 
    updateFiles(); 
}, 2000);

// Initial calls
updateDeviceStatus();
updateFiles();
```

Replace the existing `updateStatus()` function and interval with the above.

---

## Implementation Checklist

- [ ] Add `detect_camcorder()` function to `app.py`
- [ ] Add `/api/device` endpoint to `app.py`
- [ ] Replace entire `<style>` block in `templates/index.html`
- [ ] Update status display HTML structure
- [ ] Update JavaScript with device detection polling
- [ ] Test all three states: NO SIGNAL, CONNECTED, REC
- [ ] Test responsive layout on mobile

---

## Testing

### Manual Testing Steps

1. **NO SIGNAL state**: Start app without camcorder connected
   - Should show gray "NO SIGNAL" with static bars
   - Start button should be disabled

2. **CONNECTED state**: Connect DV camcorder via FireWire
   - Should show green "► CONNECTED"
   - Start button should be enabled

3. **REC state**: Start capture
   - Should show blinking red "● REC" with filename and PID
   - Stop button should be enabled

4. **Visual verification**:
   - VCR-style title with glow
   - 3D beveled buttons that press inward on click
   - Sunken input fields
   - Static scanlines overlay
   - LCD panel with inset appearance

---

## Files Modified

| File | Changes |
|------|---------|
| `app.py` | Add `detect_camcorder()` function, add `/api/device` endpoint |
| `templates/index.html` | Complete CSS redesign, update HTML structure, update JavaScript |

---

## Notes

- The scanline effect is static (not animated) per user preference
- Device detection checks `/sys/bus/firewire/devices/` for non-local devices
- All styling uses pure CSS, no external dependencies
- Monospace font stack prioritizes system fonts for authenticity
