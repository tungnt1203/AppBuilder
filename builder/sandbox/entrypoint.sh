#!/bin/sh
# Starts a project's container (as root, with NET_ADMIN only for this): walls the network off,
# then runs the command as the plain user `dev`, without any capability left. The agent runs any
# shell command in here, so what it can reach is decided here, not by what it's told:
#
# - this machine (host.docker.internal) only on SANDBOX_HOST_PORTS (the Platform's API), never
#   its other services (the Platform's database, other apps' previews, whatever else runs there)
# - no private network or cloud metadata address
# - DNS, and the internet (gems, npm, the Claude API, stock photos)
#
# Every `docker exec` runs as dev (Sandbox::Docker#exec), which can't change these rules.
set -eu

host_ip=$(getent ahostsv4 host.docker.internal | awk 'NR == 1 { print $1 }')
nameservers=$(awk '/^nameserver/ { print $2 }' /etc/resolv.conf)

iptables -F OUTPUT
iptables -P OUTPUT ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
for ns in $nameservers; do
  case "$ns" in *:*) continue ;; esac
  iptables -A OUTPUT -d "$ns" -p udp --dport 53 -j ACCEPT
  iptables -A OUTPUT -d "$ns" -p tcp --dport 53 -j ACCEPT
done
if [ -n "$host_ip" ]; then
  for port in $(echo "${SANDBOX_HOST_PORTS:-}" | tr ',' ' '); do
    iptables -A OUTPUT -d "$host_ip" -p tcp --dport "$port" -j ACCEPT
  done
  iptables -A OUTPUT -d "$host_ip" -j REJECT
fi
for range in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10; do
  iptables -A OUTPUT -d "$range" -j REJECT
done
# No IPv6 way around it.
ip6tables -P OUTPUT DROP 2>/dev/null || true
ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true

# The project's own gems volume (Sandbox::Docker) starts out root's.
mkdir -p /home/dev/gems && chown dev:dev /home/dev/gems

exec setpriv --reuid=dev --regid=dev --init-groups --inh-caps=-all --bounding-set=-all -- "$@"
