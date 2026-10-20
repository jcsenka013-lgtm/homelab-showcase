#!/bin/bash
# LAN-only filter for Docker published ports (IPv4 + IPv6).
#
# UFW does not see traffic that Docker publishes with -p / ports:.
# This fills DOCKER-USER so those ports accept LAN (and mesh VPN traffic,
# which arrives on the VPN interface) and drop everything else on the LAN NIC.
#
# Re-runnable. Do not persist these with netfilter-persistent — that snapshot
# includes Docker's runtime rules and fights dockerd on every boot.
set -euo pipefail

LAN_SUBNET="${LAN_SUBNET:-10.0.0.0/24}"
LAN_GW="${LAN_SUBNET%.*}.1"

LAN_IF=$(ip -o route get "$LAN_GW" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
[ -n "${LAN_IF:-}" ] || { echo "could not determine LAN interface" >&2; exit 1; }

LAN_V6_PREFIX="${LAN_V6_PREFIX:-}"

if ! iptables -L DOCKER-USER -n >/dev/null 2>&1; then
  echo "DOCKER-USER missing — is Docker running?" >&2
  exit 1
fi

iptables -F DOCKER-USER
# Conntrack first: replies to containers' own outbound traffic arrive on
# $LAN_IF from non-LAN sources and would otherwise be dropped.
iptables -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
iptables -A DOCKER-USER -i "$LAN_IF" ! -s "$LAN_SUBNET" -j DROP

if ip6tables -L DOCKER-USER -n >/dev/null 2>&1; then
  LAN_V6_PREFIX="${LAN_V6_PREFIX:-}"
  if [ -z "$LAN_V6_PREFIX" ]; then
    LAN_V6_PREFIX=$(ip -6 addr show dev "$LAN_IF" scope global | awk '/inet6/ && /\/64/ {print $2; exit}')
  fi

  ip6tables -F DOCKER-USER
  ip6tables -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
  if [ -n "${LAN_V6_PREFIX:-}" ]; then
    ip6tables -A DOCKER-USER -i "$LAN_IF" -s "$LAN_V6_PREFIX" -j RETURN
  fi
  ip6tables -A DOCKER-USER -i "$LAN_IF" -s fe80::/10 -j RETURN
  # Native ISP IPv6 has no NAT. Without this DROP, [::] docker-proxy ports
  # are reachable from the public internet.
  ip6tables -A DOCKER-USER -i "$LAN_IF" -j DROP
fi

echo "DOCKER-USER LAN filter applied on $LAN_IF (v4 $LAN_SUBNET${LAN_V6_PREFIX:+, v6 $LAN_V6_PREFIX})"
