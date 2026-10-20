# Architecture

## Roles

| Role | What it does |
|---|---|
| Homelab server | Single Ubuntu host running all Docker Compose stacks under `/opt/stacks` |
| Separate NAS | Long-term photo / document storage; mounted into containers as needed |
| Off-box host | Receives nightly backup copies; keeps its own retention |
| Tailscale | Remote access and HTTPS termination for phone / laptop clients |
| Home Assistant hub | Home automation (separate device; not configured in this repo) |
| Remote management | Self-hosted agent UI for desktops/laptops (separate install) |
| LAN inventory | Discovers devices on the LAN (separate install) |

## Compute

- 12th-generation Intel Core i5 class CPU
- 32GB-class RAM
- NVMe for the OS root filesystem
- NVIDIA GTX 10-series GPU available for optional photo ML acceleration
- All application containers via Docker Compose

## Storage

1. **Root NVMe** — OS, Docker engine, and (optionally) bind-mounted app data.
2. **mdadm RAID1** — two disks, filesystem label `backup`, mounted at `/srv/backup`. Nightly snapshots and database dumps land here.
3. **mergerfs pool** — additional disks combined at `/srv/pool` with create policy `mfs` and a configured `minfreespace`, so new files prefer the disk with the most free space and refuse to fill a volume past the floor.
4. **NAS mounts** — large originals (photos, documents) may stay on the separate NAS and appear inside containers as bind mounts. Databases and caches stay local under `/DATA/AppData`.

Example mergerfs fstab idea (device names are placeholders):

```
/mnt/disk1:/mnt/disk2 /srv/pool fuse.mergerfs defaults,allow_other,use_ino,category.create=mfs,minfreespace=50G 0 0
```

## Networking

- LAN: placeholder `10.0.0.0/24`, server `10.0.0.10`
- Remote access: Tailscale mesh VPN; MagicDNS style `*.example.ts.net`
- HTTPS for selected apps via `tailscale serve` (see `scripts/tailscale-serve`)
- Vaultwarden also has a LAN HTTPS reverse proxy (Caddy, internal CA) for clients that need TLS without the mesh

## App data vs. media

| Kind | Where | Why |
|---|---|---|
| Postgres / SQLite / configs | `/DATA/AppData` on local disk | Consistency, latency, backup simplicity |
| Photo originals / documents | NAS or `/srv/pool` | Capacity; NAS RAID covers drive failure, not deletion |
| Nightly snapshots | `/srv/backup` (RAID1) | Local second copy of app state |
| Off-box copies | Separate host | Survives server loss |

## Deploy layout

```
/opt/stacks/<name>/compose.yml
/opt/stacks/<name>/.env          # secrets; chmod 600; not in git
/DATA/AppData/<name>/            # persistent app state
```

Copy or symlink the scrubbed compose trees from this repo into `/opt/stacks`.
