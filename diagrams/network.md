# Network diagram (placeholder addressing)

Addresses, hostnames, and the mesh DNS suffix are examples. Replace them for
your site. Do not commit real LAN or VPN identifiers to a public copy of this
repo.

```mermaid
flowchart TB
  subgraph internet["Internet"]
    WAN["Upstream (generic ISP)"]
  end

  subgraph lan["LAN — 10.0.0.0/24"]
    GW["Gateway / router\n10.0.0.1"]
    SRV["Homelab server\n10.0.0.10\nUbuntu · Docker Compose"]
    NAS["Separate NAS\n(NFS / SMB for media & docs)"]
    HA["Home Assistant hub"]
    INV["LAN device inventory"]
    RMT["Self-hosted remote management"]
  end

  subgraph mesh["Tailscale — *.example.ts.net"]
    PHONE["Phone"]
    LAPTOP["Laptop"]
    OFFBOX["Off-box backup host"]
  end

  WAN --> GW
  GW --> SRV
  GW --> NAS
  GW --> HA
  SRV -.->|"NFS mount"| NAS
  SRV -.-> HA
  SRV -.-> INV
  SRV -.-> RMT
  PHONE -->|"HTTPS via mesh serve"| SRV
  LAPTOP --> SRV
  SRV -->|"nightly rsync (write-only)"| OFFBOX
```

## Conventions used in this showcase

| Placeholder | Meaning |
|---|---|
| `10.0.0.0/24` | Example LAN |
| `10.0.0.10` | Homelab server |
| `10.0.0.1` | LAN gateway |
| `example.ts.net` | Example Tailscale MagicDNS suffix |
| `${VAR}` | Value supplied at deploy time via `.env` |

Published Docker ports accept traffic from the LAN subnet and from the mesh
interface; WAN-facing traffic on the LAN NIC is dropped in `DOCKER-USER`
(see `system/docker-lan-filter.sh`).
