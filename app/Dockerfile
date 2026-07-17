###############################################################################
# Digital8 Appliance
#
# Purpose:
#     Reliable long-term preservation of Digital8 and MiniDV tapes.
#
# Design goals:
#     • Simple enough to reinstall in under 10 minutes.
#     • No cloud dependencies.
#     • Rootless deployment.
#     • Captures written directly to Synology over NFS.
#     • Recover automatically after reboot.
#     • No manual intervention during multi-hour capture sessions.
#
# Nearly every design decision in this image exists because it solved a real
# hardware or Linux compatibility problem encountered during testing.
# Please read the comments before simplifying anything.
###############################################################################

###############################################################################
# Container Security and FireWire Access
#
# This image intentionally runs as UID 0 inside the container.
#
# Security:
#   - The container is executed by rootless Podman.
#   - Container UID 0 is mapped through a rootless user namespace.
#   - It does not have host-root privileges.
#
# FireWire:
#   - Digital8/DV capture requires direct access to /dev/fw0 and /dev/fw1.
#   - Running the application as container UID 1000 was tested.
#   - NFS write access worked, but FireWire device access failed.
#
# Verified with UID 1000:
#   ✓ Gunicorn startup
#   ✓ NFS write access
#   ✗ /dev/fw0 read/write access
#   ✗ /dev/fw1 read/write access
#
# Running as container UID 0 restored:
#   ✓ Sony DCR-TRV120 detection
#   ✓ AV/C transport control
#   ✓ dvgrab capture
#   ✓ Stable Digital8/DV recording
#
# This image is intended only for rootless Podman.
# Do not run it as a privileged container or from a host-root Podman service.
###############################################################################

FROM python:3.11-slim

LABEL org.opencontainers.image.title="dvgrab-WebUI"
LABEL org.opencontainers.image.description="Digital8/DV capture WebUI using dvgrab and Gunicorn"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# dvgrab: FireWire DV capture
# procps: process inspection/management used by some WebUI functions
# tini: clean signal forwarding and zombie-process reaping
# curl: container health checks
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dvgrab \
        procps \
        tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN python -m pip install \
        "Flask>=3.0,<4.0" \
        "gunicorn>=22,<24"

COPY app.py /app/app.py
COPY templates/ /app/templates/
COPY static/ /app/static/

# The Quadlet bind-mounts the Synology capture directory over this path.
RUN mkdir -p /captures

EXPOSE 5000

###############################################################################
# OCI Image Format
#
# This project builds native OCI images because Podman/Quadlet are the
# deployment targets.
#
# OCI images currently ignore Docker HEALTHCHECK directives.
#
# Service health is instead provided by:
#
#   • systemd (Quadlet)
#   • Podman restart policies
#   • the WebUI /api/status endpoint
#
# The HEALTHCHECK remains documented for compatibility with Docker-based
# deployments in the future.   You may uncomment it for Docker-base deployments
#
#
###############################################################################
# HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
#    CMD curl --fail --silent http://127.0.0.1:5000/ >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]


###############################################################################
# Gunicorn Configuration
#
# Important:  This application intentionally uses:
#
#     --workers 1
#
# The Flask application manages a single dvgrab process and stores capture
# state in memory.
#
# Multiple Gunicorn workers would each maintain independent application state,
# potentially resulting in:
#
#   • Multiple simultaneous dvgrab processes
#   • Incorrect capture status reporting
#   • Race conditions when stopping a capture
#   • Conflicting access to the FireWire device
#
# Horizontal scaling provides no benefit for this appliance because the
# hardware can only capture one DV stream at a time.
###############################################################################

#CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "4", "--timeout", "0", "--graceful-timeout", "30", "--keep-alive", "5", "--access-logfile", "-", "--error-logfile", "-", "--capture-output", "app:app"]
# Reduce log noise
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "4", "--timeout", "0", "--graceful-timeout", "30", "--keep-alive", "5", "--error-logfile", "-", "--capture-output", "app:app"]
