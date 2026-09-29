#!/bin/sh
set -ex

echo "=== 1. ネットワーク設定の適用 (/etc/config/network) ==="
# eth1 を収容するブリッジデバイスの定義
uci -q delete network.br_lan
uci set network.br_lan=device
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'
uci set network.br_lan.ports='eth1'

# LANインターフェースの定義 (192.168.1.1/24)
uci -q delete network.lan
uci set network.lan=interface
uci set network.lan.device='br-lan'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.1'
uci set network.lan.netmask='255.255.255.0'

# WANインターフェースの定義 (eth0: 上位ルータからDHCP取得)
uci -q delete network.wan
uci set network.wan=interface
uci set network.wan.device='eth0'
uci set network.wan.proto='dhcp'

uci commit network

echo "=== 2. DHCP設定の適用 (/etc/config/dhcp) ==="
# LAN側: 192.168.1.100〜249 を配布
uci -q delete dhcp.lan
uci set dhcp.lan=dhcp
uci set dhcp.lan.interface='lan'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

# WAN側: DHCPサーバを無効化
uci -q delete dhcp.wan
uci set dhcp.wan=dhcp
uci set dhcp.wan.interface='wan'
uci set dhcp.wan.ignore='1'

uci commit dhcp

echo "=== 3. ファイアウォール設定の適用 (/etc/config/firewall) ==="
# LANゾーンの定義
uci -q delete firewall.zone_lan
uci set firewall.zone_lan=zone
uci set firewall.zone_lan.name='lan'
uci set firewall.zone_lan.network='lan'
uci set firewall.zone_lan.input='ACCEPT'
uci set firewall.zone_lan.output='ACCEPT'
uci set firewall.zone_lan.forward='ACCEPT'

# WANゾーンの定義 (マスカレード有効)
uci -q delete firewall.zone_wan
uci set firewall.zone_wan=zone
uci set firewall.zone_wan.name='wan'
uci set firewall.zone_wan.network='wan'
uci set firewall.zone_wan.input='REJECT'
uci set firewall.zone_wan.output='ACCEPT'
uci set firewall.zone_wan.forward='REJECT'
uci set firewall.zone_wan.masq='1'
uci set firewall.zone_wan.mtu_fix='1'

# LANからWANへのインターネット通信転送
uci -q delete firewall.fwd_lan_wan
uci set firewall.fwd_lan_wan=forwarding
uci set firewall.fwd_lan_wan.src='lan'
uci set firewall.fwd_lan_wan.dest='wan'

# 上位ネットワーク (192.168.40.0/24) へのアクセスを完全遮断
uci -q delete firewall.block_upstream
uci set firewall.block_upstream=rule
uci set firewall.block_upstream.name='Block-Upstream-LAN'
uci set firewall.block_upstream.src='lan'
uci set firewall.block_upstream.dest='*'
uci set firewall.block_upstream.dest_ip='192.168.40.0/24'
uci set firewall.block_upstream.target='REJECT'

uci commit firewall

echo "=== 4. 関連サービスの再起動 ==="
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

echo "=== 設定が正常に完了しました ==="

set +x
