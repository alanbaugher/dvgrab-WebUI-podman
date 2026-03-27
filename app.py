from flask import Flask, render_template, jsonify, send_file, request
import subprocess
import os
import threading
import glob

app = Flask(__name__)

CAPTURE_DIR = "/captures"
capture_process = None
capture_status = {"running": False, "filename": None, "pid": None}

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
                    if f.read().strip() == "0":
                        return True
    except (IOError, OSError):
        pass
    return False

def get_files():
    files = []
    for ext in ["*.dv", "*.avi", "*.mov", "*.mkv"]:
        files.extend(glob.glob(os.path.join(CAPTURE_DIR, ext)))
    files.sort(key=os.path.getmtime, reverse=True)
    return [{"name": os.path.basename(f), "size": os.path.getsize(f)} for f in files]

@app.route("/")
def index():
    return render_template("index.html", files=get_files(), status=capture_status)

@app.route("/api/start", methods=["POST"])
def start_capture():
    global capture_process, capture_status
    
    if capture_status["running"]:
        return jsonify({"error": "Capture already running"}), 400
    
    data = request.get_json() or {}
    prefix = data.get("prefix", "capture-")
    fmt = data.get("format", "dv2")
    autosplit = data.get("autosplit", False)
    
    cmd = ["dvgrab", "-f", fmt, "-card", "0"]
    if autosplit:
        cmd.append("-autosplit")
    cmd.append(os.path.join(CAPTURE_DIR, prefix))
    
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
            "format": fmt,
            "autosplit": autosplit
        }
        return jsonify({"status": "started", "pid": capture_process.pid})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/stop", methods=["POST"])
def stop_capture():
    global capture_process, capture_status
    
    if not capture_status["running"] or not capture_process:
        return jsonify({"error": "No capture running"}), 400
    
    try:
        capture_process.terminate()
        capture_process.wait(timeout=5)
        capture_status = {"running": False, "filename": None, "pid": None}
        return jsonify({"status": "stopped"})
    except subprocess.TimeoutExpired:
        capture_process.kill()
        capture_status = {"running": False, "filename": None, "pid": None}
        return jsonify({"status": "killed"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/status")
def status():
    return jsonify(capture_status)

@app.route("/api/device")
def device_status():
    """Return whether a DV camcorder is connected"""
    return jsonify({"connected": detect_camcorder()})

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

if __name__ == "__main__":
    os.makedirs(CAPTURE_DIR, exist_ok=True)
    app.run(host="0.0.0.0", port=5000)
