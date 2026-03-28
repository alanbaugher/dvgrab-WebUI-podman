# Plan: Dynamic FireWire Card Detection

## Summary
Make the dvgrab capture system automatically detect which FireWire port the camcorder is connected to, instead of hardcoding card 0.

## Changes

### 1. app.py - Enhance `detect_camcorder()` function
- Add `card` field to the returned dict
- Extract card number from device name (e.g., `fw1` -> card `1`)
- Device name parsing: `fw{N}` or `fw{N}.{M}` -> card number is `{N}`

### 2. app.py - Update `start_capture()` function
- Call `detect_camcorder()` to get the card number
- Use detected card number in dvgrab command: `-card {N}`
- Return error if no camcorder detected or card cannot be determined
- Include card number in capture_status

### 3. docker-compose.yml - Pass multiple FireWire devices
- Add `/dev/fw1`, `/dev/fw2`, `/dev/fw3` to cover typical multi-port setups
- Docker will silently ignore devices that don't exist on the host

## Files Modified
- app.py
- docker-compose.yml
