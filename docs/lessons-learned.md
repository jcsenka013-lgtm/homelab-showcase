# Lessons learned

Hard-won notes from running this layout on a single Ubuntu host. Written so
they transfer to another site without naming a specific home network.

## 1. Published Docker ports are not “behind UFW”

Docker's `-p` / `ports:` path bypasses typical host firewall frontends. On
native IPv6 there is often no NAT, so a forgotten `[::]` listen can mean the
whole internet can reach an admin UI. Fix at `DOCKER-USER` (IPv4 and IPv6),
re-apply when dockerd recreates the chain, and treat mesh VPN as the remote
path instead of port-forwarding the ISP router. Tailscale is that remote path
here; do not open WAN port-forwards on the gateway.

## 2. Keep databases on local disk

Putting SQLite (or busy Postgres) on a NAS share looks tidy until permission
quirks, latency, or a stale mount produce multi-gigabyte log loops and corrupt
indexes. Pattern that worked: originals and large media on the NAS or mergerfs
pool; AppData (DBs, configs, caches) on local NVMe/SSD under `/DATA/AppData`.

## 3. Nightly snapshots need consistency tricks

Plain `rsync` of live SQLite files can capture a torn page. After each
snapshot, re-copy every `.db` / `.sqlite*` with SQLite's online backup API.
For Postgres, prefer `pg_dumpall` over copying `pgdata/` while the server runs.
Exclude regenerable caches so retention stays cheap; use `--link-dest` so
unchanged files are hard-linked across days.

## 4. Off-box copy should be write-only from the server

A second disk in the same chassis does not survive theft, fire, or ransomware
on the server. Pushing to another host helps only if a compromised server
cannot wipe the remote copies. `rrsync -wo -no-del` plus pruning **on the
receiver** is a simple, effective split of duties.

## 5. mergerfs with `mfs` + `minfreespace`

Spreading disks with “most free space” create policy avoids filling one drive
while others sit empty. `minfreespace` stops the pool from accepting new files
onto a nearly full member, which is easier to reason about than surprising
ENOSPC mid-ingest.

## 6. Alerts must not depend on a local mail stack

`MAILADDR root` with no sendmail is silent failure. Route mdadm, SMART, and
systemd `OnFailure=` through a self-hosted ntfy topic, and make the sender
fall back to the journal if the notifier is down so a dead ntfy does not hide
the original fault forever.

## 7. Mesh HTTPS without a reverse-proxy farm

Per-app HTTPS ports via the mesh client's `serve` (HTTPS port = 10000 + HTTP
port, with the dashboard on 443) avoided running a full Traefik/Caddy edge for
every container. Keep a small LAN TLS helper only where clients insist on
HTTPS without the mesh (password manager).

## 8. Idempotent prep scripts beat tribal knowledge

Host setup that is safe to re-run (`server-prep`, `offbox-setup`) survives
rebuilds and makes the “how did we get here?” question answerable from git.
Prompt hard before any wipe; identify disks by stable `/dev/disk/by-id`
symlinks in production — this showcase keeps those identifiers out of the
published tree on purpose.

## 9. Document the live layout, not the archaeology

Storage paths and GPU roles change. Portfolio and grant material should match
what is running now (one server, RAID1 + mergerfs pool, NVIDIA for optional ML)
rather than older multi-mount layouts from migration notes.
