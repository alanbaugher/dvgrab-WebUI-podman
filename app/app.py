from flask import Flask, render_template, jsonify, send_file, request
import subprocess
import os
import threading
import glob
import logging

app = Flask(__name__, static_folder='static')
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

VERSION = "0.4.0"
CAPTURE_DIR = "/captures"
capture_process = None
capture_status = {"running": False, "filename": None, "pid": None, "profile": None, "format": None, "autosplit": False, "rewind": False, "last_error": None}
capture_stderr = []

CAPTURE_PROFILES = {
    "archival": {
        "label": "Archival (recommended)",
        "format": "dv2",
        "autosplit": True,
        "rewind": True,
    },
    "raw": {
        "label": "Raw DV",
        "format": "raw",
        "autosplit": True,
        "rewind": True,
    },
    "quick": {
        "label": "Quick test",
        "format": "dv2",
        "autosplit": False,
        "rewind": True,
    },
    "custom": {
        "label": "Custom",
        "format": None,
        "autosplit": None,
        "rewind": None,
    },
}

ALLOWED_FORMATS = {"dv1", "dv2", "raw", "mov"}


def check_device_ready(device_path):
    """Check if device is fully initialized and ready for capture"""
    config_rom_path = os.path.join(device_path, "config_rom")
    units_path = os.path.join(device_path, "units")
    
    try:
        if os.path.exists(config_rom_path):
            config_rom = open(config_rom_path, "rb").read()
            if not config_rom or len(config_rom) < 8:
                return False
        else:
            return False
        
        if os.path.exists(units_path):
            units = open(units_path, "rb").read()
            if not units:
                return False
        else:
            return False
        
        return True
    except (IOError, OSError):
        return False

def detect_camcorder():
    """Check if a DV camcorder is connected via FireWire/IEEE 1394"""
    devices_path = "/sys/bus/firewire/devices/"
    result = {"connected": False, "ready": False, "vendor": None, "model": None, "guid": None}
    
    if not os.path.exists(devices_path):
        return result
    
    try:
        for device in os.listdir(devices_path):
            device_path = os.path.join(devices_path, device)
            is_local_path = os.path.join(device_path, "is_local")
            if os.path.exists(is_local_path):
                with open(is_local_path) as f:
                    if f.read().strip() == "0":
                        vendor_path = os.path.join(device_path, "vendor_name")
                        model_path = os.path.join(device_path, "model_name")
                        guid_path = os.path.join(device_path, "guid")
                        
                        try:
                            if os.path.exists(vendor_path):
                                result["vendor"] = open(vendor_path).read().strip()
                        except:
                            pass
                        try:
                            if os.path.exists(model_path):
                                result["model"] = open(model_path).read().strip()
                        except:
                            pass
                        try:
                            if os.path.exists(guid_path):
                                result["guid"] = open(guid_path).read().strip()
                        except:
                            pass
                        
                        result["connected"] = True
                        result["ready"] = check_device_ready(device_path)
                        return result
    except (IOError, OSError):
        pass
    return result

def get_files():
    files = []
    for ext in ["*.dv", "*.avi", "*.mov", "*.mkv"]:
        files.extend(glob.glob(os.path.join(CAPTURE_DIR, ext)))
    files.sort(key=os.path.getmtime, reverse=True)
    return [{"name": os.path.basename(f), "size": os.path.getsize(f)} for f in files]

def monitor_capture():
    global capture_process, capture_status, capture_stderr
    if capture_process:
        stdout, stderr = capture_process.communicate()
        returncode = capture_process.returncode
        if returncode != 0:
            logger.error(f"dvgrab exited with code {returncode}: {stderr}")
            capture_status["last_error"] = f"Exit code {returncode}: {stderr.strip()}" if stderr.strip() else f"Exit code {returncode}"
        else:
            logger.info(f"dvgrab exited normally")
        capture_process = None
        capture_status["running"] = False
        capture_status["pid"] = None

@app.route("/")
def index():
    return render_template("index.html", files=get_files(), status=capture_status)

@app.route("/api/start", methods=["POST"])
def start_capture():
    global capture_process, capture_status, capture_stderr
    
    if capture_status["running"]:
        return jsonify({"error": "Capture already running"}), 400
    
    data = request.get_json() or {}
    prefix = str(data.get("prefix", "DV-")).strip() or "DV-"
    profile = str(data.get("profile", "archival")).strip().lower()

    if profile not in CAPTURE_PROFILES:
        return jsonify({"error": f"Unknown capture profile: {profile}"}), 400

    profile_settings = CAPTURE_PROFILES[profile]
    if profile == "custom":
        fmt = str(data.get("format", "dv2")).strip().lower()
        autosplit = bool(data.get("autosplit", False))
        rewind = bool(data.get("rewind", True))
    else:
        fmt = profile_settings["format"]
        autosplit = profile_settings["autosplit"]
        rewind = profile_settings["rewind"]

    if fmt not in ALLOWED_FORMATS:
        return jsonify({"error": f"Unsupported capture format: {fmt}"}), 400
    
    device = detect_camcorder()
    if not device.get("connected"):
        return jsonify({"error": "No camera connected"}), 400
    if not device.get("ready"):
        return jsonify({"error": "Camera not ready - wait a moment and try again"}), 400
    
    cmd = ["dvgrab", "-f", fmt]

    # AVI Type-1 and Type-2 need OpenDML for files larger than the
    # traditional AVI size limits. --size 0 disables size-based splitting.
    if fmt in {"dv1", "dv2"}:
        cmd.extend(["--opendml", "--size", "0"])

    if device.get("guid"):
        cmd.extend(["-guid", device["guid"]])
    if autosplit:
        cmd.append("-autosplit")
    if rewind:
        cmd.append("--rewind")
    cmd.append(os.path.join(CAPTURE_DIR, prefix))
    
    def try_capture(retry_count=0):
        global capture_process, capture_status, capture_stderr
        try:
            capture_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            capture_status = {
                "running": True,
                "filename": prefix,
                "pid": capture_process.pid,
                "profile": profile,
                "format": fmt,
                "autosplit": autosplit,
                "rewind": rewind,
                "last_error": None
            }
            capture_stderr = []
            
            def monitor_with_retry():
                global capture_process, capture_status
                import time
                start_time = time.time()
                
                while capture_process and time.time() - start_time < 3:
                    poll_result = capture_process.poll()
                    if poll_result is not None:
                        _, stderr = capture_process.communicate()
                        if poll_result != 0 and retry_count < 1:
                            logger.warning(f"dvgrab failed quickly (code {poll_result}), retrying after 2s...")
                            time.sleep(2)
                            capture_process = None
                            try_capture(retry_count + 1)
                            return
                        else:
                            monitor_capture()
                            return
                    time.sleep(0.1)
                
                if capture_process:
                    monitor_thread = threading.Thread(target=monitor_capture, daemon=True)
                    monitor_thread.start()
            
            monitor_thread = threading.Thread(target=monitor_with_retry, daemon=True)
            monitor_thread.start()
            logger.info(f"Started dvgrab with PID {capture_process.pid}: {' '.join(cmd)}")
            return None
        except Exception as e:
            logger.error(f"Failed to start dvgrab: {e}")
            return str(e)
    
    error = try_capture()
    if error:
        return jsonify({"error": error}), 500
    return jsonify({"status": "started", "pid": capture_status["pid"]})

@app.route("/api/stop", methods=["POST"])
def stop_capture():
    global capture_process, capture_status
    
    if not capture_status["running"] or not capture_process:
        return jsonify({"error": "No capture running"}), 400
    
    try:
        capture_process.terminate()
        capture_process.wait(timeout=5)
        logger.info(f"dvgrab terminated normally (PID {capture_status['pid']})")
    except subprocess.TimeoutExpired:
        capture_process.kill()
        capture_process.wait()
        logger.warning(f"dvgrab killed after timeout (PID {capture_status['pid']})")
    except Exception as e:
        logger.error(f"Error stopping dvgrab: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        capture_process = None
        capture_status = {"running": False, "filename": None, "pid": None, "profile": None, "format": None, "autosplit": False, "rewind": False, "last_error": None}
    
    return jsonify({"status": "stopped"})

@app.route("/api/status")
def status():
    global capture_process, capture_status
    if capture_status["running"] and capture_process:
        poll_result = capture_process.poll()
        if poll_result is not None:
            _, stderr = capture_process.communicate()
            if poll_result != 0:
                capture_status["last_error"] = f"Process died (code {poll_result}): {stderr.strip()}" if stderr.strip() else f"Process died (code {poll_result})"
            capture_status["running"] = False
            capture_status["pid"] = None
            capture_process = None
            logger.warning(f"dvgrab process died unexpectedly: {capture_status.get('last_error')}")
    return jsonify(capture_status)

@app.route("/api/profiles")
def get_profiles():
    return jsonify(CAPTURE_PROFILES)

@app.route("/api/version")
def get_version():
    return jsonify({"version": VERSION})

@app.route("/api/device")
def device_status():
    """Return DV camcorder connection status and device info"""
    return jsonify(detect_camcorder())

@app.route("/api/files")
def list_files():
    return jsonify(get_files())

@app.route("/api/download/<filename>")
def download_file(filename):
    filepath = os.path.join(CAPTURE_DIR, filename)
    if os.path.exists(filepath):
        return send_file(filepath, as_attachment=True)
    return jsonify({"error": "File not found"}), 404

@app.route("/api/delete/<filename>", methods=["DELETE"])
def delete_file(filename):
    filepath = os.path.join(CAPTURE_DIR, filename)
    if os.path.exists(filepath):
        os.remove(filepath)
        return jsonify({"status": "deleted"})
    return jsonify({"error": "File not found"}), 404


# For development only.
# Production uses Gunicorn (see Dockerfile).
if __name__ == "__main__":
    os.makedirs(CAPTURE_DIR, exist_ok=True)
    app.run(host="0.0.0.0", port=5000)
