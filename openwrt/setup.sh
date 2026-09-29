#!/bin/sh
# ==============================================================================
# OpenWrt Network Provisioning Script: Isolated Downstream Client Network
#
# Topology:
#   - eth0 (WAN): Obtains IP via DHCP from the upstream network (192.168.40.0/24).
#   - eth1 (LAN): Isolated downstream bridge (br-lan) serving 192.168.1.0/24.
#
# Security Policy:
#   - Forwarding from LAN to WAN is permitted for regular internet access.
#   - Any traffic from LAN targeting 192.168.40.0/24 is explicitly rejected.
# ==============================================================================

# Halt script execution immediately if any command returns a non-zero exit status
set -e

echo "[+] Starting network and firewall configuration..."

# ------------------------------------------------------------------------------
# 1. Network Interface Setup (/etc/config/network)
# ------------------------------------------------------------------------------
echo "[+] Step 1: Configuring bridge and logical interfaces in /etc/config/network"

# Define the bridge device (br-lan) accommodating only the downstream port (eth1)
uci -q delete network.br_lan
uci set network.br_lan=device
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'
uci set network.br_lan.ports='eth1'

# Configure the LAN logical interface with a static gateway IP
uci set network.lan.device='br-lan'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.1'
uci set network.lan.netmask='255.255.255.0'

# Configure the WAN logical interface to acquire upstream addresses dynamically
uci set network.wan.device='eth0'
uci set network.wan.proto='dhcp'

# Commit all network changes to persistent storage
uci commit network
echo "[+] Network configuration committed successfully."

# ------------------------------------------------------------------------------
# 2. DHCP and DNS Service Setup (/etc/config/dhcp)
# ------------------------------------------------------------------------------
echo "[+] Step 2: Configuring DHCP pool parameters in /etc/config/dhcp"

# Directly update existing dhcp.lan section attributes to prevent parse aborts
uci set dhcp.lan.interface='lan'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

# Suppress DHCP server execution on the upstream WAN interface
uci set dhcp.wan.interface='wan'
uci set dhcp.wan.ignore='1'

# Commit all DHCP changes to persistent storage
uci commit dhcp
echo "[+] DHCP parameters committed successfully."

# ------------------------------------------------------------------------------
# 3. Firewall and Subnet Isolation Setup (/etc/config/firewall)
# ------------------------------------------------------------------------------
echo "[+] Step 3: Configuring firewall policies and isolation filters in /etc/config/firewall"

# Explicitly define the LAN firewall zone using a unique section identifier
uci -q delete firewall.zone_lan
uci set firewall.zone_lan=zone
uci set firewall.zone_lan.name='lan'
uci set firewall.zone_lan.network='lan'
uci set firewall.zone_lan.input='ACCEPT'
uci set firewall.zone_lan.output='ACCEPT'
uci set firewall.zone_lan.forward='ACCEPT'

# Explicitly define the WAN firewall zone with source NAT masquerade enabled
uci -q delete firewall.zone_wan
uci set firewall.zone_wan=zone
uci set firewall.zone_wan.name='wan'
uci set firewall.zone_wan.network='wan'
uci set firewall.zone_wan.input='REJECT'
uci set firewall.zone_wan.output='ACCEPT'
uci set firewall.zone_wan.forward='REJECT'
uci set firewall.zone_wan.masq='1'
uci set firewall.zone_wan.mtu_fix='1'

# Define forwarding directive allowing outbound transit traffic from LAN to WAN
uci -q delete firewall.fwd_lan_wan
uci set firewall.fwd_lan_wan=forwarding
uci set firewall.fwd_lan_wan.src='lan'
uci set firewall.fwd_lan_wan.dest='wan'

# Enforce upstream subnet isolation:
# Reject all transit packets from LAN directed toward the 192.168.40.0/24 subnet.
# Using dest='*' prevents routing bypasses across any evaluated outbound zone.
uci -q delete firewall.block_upstream
uci set firewall.block_upstream=rule
uci set firewall.block_upstream.name='Block-Upstream-LAN'
uci set firewall.block_upstream.src='lan'
uci set firewall.block_upstream.dest='*'
uci set firewall.block_upstream.dest_ip='192.168.40.0/24'
uci set firewall.block_upstream.target='REJECT'

# Commit all firewall rules to persistent storage
uci commit firewall
echo "[+] Firewall rules committed successfully."

# ------------------------------------------------------------------------------
# 4. Daemon Reload and Verification
# ------------------------------------------------------------------------------
echo "[+] Step 4: Restarting system daemons to load the active configuration..."

/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

echo "[+] Waiting 3 seconds for network interfaces and routing tables to settle..."
sleep 3

# Verify that the block rule loaded into the active nftables ruleset
if nft list ruleset | grep -q "192.168.40.0/24"; then
    echo "[+] Firewall verification passed: Isolation rule is active in nftables."
else
    echo "[!] Warning: Isolation rule not found in active nftables table." >&2
fi

echo "=============================================================================="
echo " Deployment Complete!"
echo " - LAN Gateway: 192.168.1.1 (eth1, DHCP Range: 192.168.1.100 - 192.168.1.249)"
echo " - WAN Uplink:  DHCP (eth0)"
echo " - Blocked:     192.168.40.0/24"
echo "=============================================================================="