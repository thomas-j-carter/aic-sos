
# Connector rollout policy (MVP→v1)

- Connectors are SemVer artifacts, tenant-pinnable.
- Patch auto-update allowed (standard ring).
- Minor versions opt-in (or preview-only auto-update).
- Major versions require explicit tenant approval + migration notes.
- Contract tests against vendor sandbox + recorded fixtures gate releases.
- Emergency vendor-forced changes follow exception process (Security + Architecture sign-off).
