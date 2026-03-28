# Device Info Display Enhancement

## Overview
Add vendor and model name display when a DV camcorder is connected.

## Current State
- Backend returns only `{"connected": boolean}` from `/api/device`
- Frontend shows "► CONNECTED" when device is detected
- FireWire sysfs provides `vendor_name` and `model_name` attributes

## Implementation

### 1. Backend Changes (`app.py`)

**Modify `detect_camcorder()` function (lines 13-28):**
- Change return type from boolean to dict
- Read `vendor_name` and `model_name` from sysfs when device found
- Return structure: `{"connected": True, "vendor": "Sony", "model": "DCR-PC110E"}`

**Update `/api/device` endpoint (lines 99-102):**
- Pass through the full dict from `detect_camcorder()`

### 2. Frontend Changes (`templates/index.html`)

**Update `updateDeviceStatus()` function:**
- Store device info in a global variable for use by `updateStatusDisplay()`

**Update `updateStatusDisplay()` function:**
- When connected, display: `► CONNECTED - Sony DCR-PC110E`
- Fallback to just "► CONNECTED" if vendor/model unavailable

## Files Modified
1. `/home/thorsten/dvgrab-web/app.py` - Backend device detection
2. `/home/thorsten/dvgrab-web/templates/index.html` - Frontend display

## Testing
1. Connect FireWire camcorder
2. Verify LCD shows "► CONNECTED - [Vendor] [Model]"
3. Disconnect and verify "NO SIGNAL" appears
