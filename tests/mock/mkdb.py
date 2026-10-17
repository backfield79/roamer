#!/usr/bin/env python3
"""Build the fake UCI database for one test: mkdb.py <out.json> [key=value …]
   lanip=192.168.1.1  wanbr=1 (WAN inside br-lan)  hostname=OpenWrt"""
import json, sys
opt = dict(a.split('=', 1) for a in sys.argv[2:])
d = {'t': {}, 'o': {}, 'order': [], 'anon': {}}
def sec(n, t, **o):
    d['t'][n] = t; d['order'].append(n); d['o'][n] = o
sec('wireless.radio0', 'wifi-device', band='2g', channel='1', htmode='HT20')
sec('wireless.default_radio0', 'wifi-iface', device='radio0', mode='ap', network='lan', ssid='OpenWrt', encryption='none')
sec('wireless.radio1', 'wifi-device', band='5g', channel='36', htmode='HE80')
sec('wireless.default_radio1', 'wifi-iface', device='radio1', mode='ap', network='lan', ssid='OpenWrt', encryption='none')
ports = ['lan1', 'lan2', 'lan3', 'lan4'] + (['wan'] if opt.get('wanbr') == '1' else [])
sec('network.cfg030f15', 'device', name='br-lan', type='bridge', ports=ports)
sec('network.lan', 'interface', device='br-lan', proto='static', ipaddr=opt.get('lanip', '192.168.1.1'), netmask='255.255.255.0')
sec('network.wan', 'interface', device='wan', proto='dhcp')
sec('network.wan6', 'interface', device='wan', proto='dhcpv6')
sec('dhcp.lan', 'dhcp', interface='lan')
sec('system.cfg01', 'system', hostname=opt.get('hostname', 'OpenWrt')); d['anon']['system.cfg01'] = 'system.@system[0]'
json.dump(d, open(sys.argv[1], 'w'))
