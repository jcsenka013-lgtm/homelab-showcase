# Security hardening

## Docker port publishing

UFW does not see traffic that Docker publishes with `ports:`. Published
containers can be reachable from the WAN, especially on IPv6 where there is
often no NAT.

`system/docker-lan-filter.sh` fills the `DOCKER-USER` chain so that:

1. Established/related replies are allowed (containers' own outbound traffic).
2. On the LAN NIC, non-LAN IPv4 sources are dropped.
3. On IPv6, link-local and the configured LAN prefix are allowed; everything
   else on the LAN NIC is dropped.

Tailscale traffic arrives on the VPN interface and is not hit by the LAN-NIC
DROP. Re-apply on Docker start via the systemd drop-in in
`system/docker.service.d-lan-filter.conf`.

Configure the LAN with environment overrides, for example:

```bash
LAN_SUBNET=10.0.0.0/24 sudo system/docker-lan-filter.sh
```

## Secrets

- Per-stack `.env` next to `compose.yml` (mode `600`, owner is the deploy user).
- Templates use `${VAR:?set in .env}` so a missing secret fails fast.
- `.gitignore` excludes `.env`, key material, DB dumps, and password exports.
- Vaultwarden: `SIGNUPS_ALLOWED=false`, `ADMIN_TOKEN` required.

## HTTPS

- Tailscale `serve` issues certificates for phone/laptop clients
  (`scripts/tailscale-serve`).
- Vaultwarden LAN path: Caddy with `tls internal` reverse-proxies to the
  container HTTP port so Bitwarden clients get HTTPS on the LAN without
  exposing plaintext.

## Alerts

SMART health, mdadm array events, and failed systemd units push to a
self-hosted ntfy topic (`${NTFY_TOPIC}`). If ntfy is down, `ntfy-send` logs to
the journal instead of failing the caller.

## Host prep

`scripts/server-prep` is idempotent and includes:

- Docker Engine from distro packages (log rotation, live-restore)
- Raised inotify limits for file-watching apps
- RAID1 assembly for `/srv/backup`
- NFS client mount to a separate NAS (optional)
- Backup timer + off-box SSH key generation
- SMART / mdadm → ntfy wiring

Review wipe prompts carefully; disk steps refuse to continue unless you type
`wipe`.
