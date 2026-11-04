## [1.1.0] (openGym 1.4.3)

### Changed

- The app now runs openGym as the unprivileged user `coach` and nginx as the unprivileged user `nginx`, instead of root.
- Existing data in `/data/opengym` is re-owned to `coach` once, at the first start after the update. Nothing else in it changes.
- The Supervisor token is only held by the short start-up step: once the address is known, the start-up script replaces itself with a copy without the token, so neither openGym, nginx nor the script that supervises them holds it.
- The build also installs `su-exec` from Alpine's package mirrors.

### If the update fails

Restore the backup Home Assistant made before the update (**Settings > System > Backups**, the partial backup of openGym). The data is the same files in both versions; only their owner changes, and 1.0.2 runs as root, so it reads them either way.

## [1.0.2] (openGym 1.4.3)

### Changed

- The openGym base images are pinned by digest as well as by tag, so a re-pushed tag cannot change what gets built.

### Added

- README sections on what the app touches and how it is made, SECURITY.md, a funding file, and a release workflow.

## [1.0.1] (openGym 1.4.3)

An IP address is refused as the address: passkeys never work on one.

## [1.0.0] (openGym 1.4.3)

First release.
