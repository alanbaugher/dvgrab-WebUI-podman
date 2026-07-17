# Design Decisions

This document explains why certain implementation decisions were made.

---

# Rootless Podman

The appliance runs entirely under rootless Podman.

Advantages

- No host root daemon
- Easier recovery
- Better isolation
- Simpler deployment

---

# Container Root User

The application intentionally runs as UID 0 inside the container.

This is NOT host root.

Container UID 0 maps to the invoking user through rootless Podman.

Attempts were made to run as an unprivileged container user.

Results

✓ Gunicorn worked

✓ Flask worked

✓ NFS writes worked

✗ FireWire device access failed

Reverting to container UID 0 restored reliable FireWire access.

---

# Gunicorn

Gunicorn replaces the Flask development server.

Configuration

```
workers = 1
threads = 4
```

Only one worker is used.

The application maintains capture state in memory.

Multiple workers could:

- start multiple dvgrab processes
- report conflicting status
- race when stopping capture

Since one FireWire bus can only capture one tape, additional workers provide no benefit.

---

# OCI Images

The project builds OCI images.

Deployment target

- Podman
- Quadlet

Docker compatibility is retained where practical.

---

# Health Checks

OCI currently ignores Docker HEALTHCHECK directives.

Service health is instead provided by

- Quadlet
- systemd
- Podman restart policy
- WebUI API endpoints

---

# Storage

Captured files are written directly to the Synology NFS share.

No local staging area is used.

Advantages

- Immediate backup
- No disk duplication
- Simpler recovery

---

# Philosophy

Every design decision exists because it solved an actual problem encountered during testing.

Before changing any "odd-looking" implementation, review the associated comments and documentation.
