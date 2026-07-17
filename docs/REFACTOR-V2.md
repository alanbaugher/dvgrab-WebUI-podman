# Lifecycle Script Refactor v2

## Changes

- `status.sh` is compact by default.
- `status.sh --verbose` provides the full diagnostic report.
- `install.sh` no longer restarts an already-running service by default.
- `install.sh --restart` explicitly applies image or Quadlet changes.
- `update.sh` follows the same non-disruptive model.
- Build-state hashing includes only active build inputs.
- API calls are centralized in `lib/common.sh`.
- `validate.sh` performs syntax, deployment, storage, FireWire, image, and API checks.
- `cleanup.sh` provides a dry-run cleanup of generated and backup files.
- Quadlet backups are created only when the installed definition changes.

## Safe test order

```bash
./cleanup.sh
./validate.sh
./status.sh
./status.sh --verbose
./install.sh
./install.sh --restart
./stop.sh
./start.sh
./validate.sh
```

Run `./cleanup.sh --apply` only after reviewing the dry-run list.
