#!/usr/bin/env python3
# test stand-in for OpenWrt's /bin/ipcalc.sh: ipcalc.sh <ip>[/<prefix|mask>] [<start> <limit>]
import sys, ipaddress
a = sys.argv[1:]
ip, _, m = a[0].partition('/')
m = m or '24'
net = ipaddress.ip_network(f"{ip}/{m}", strict=False)
print(f"IP={ip}\nNETMASK={net.netmask}\nBROADCAST={net.broadcast_address}\nNETWORK={net.network_address}\nPREFIX={net.prefixlen}")
if len(a) >= 3:
    s = int(net.network_address) + int(a[1]); e = min(s + int(a[2]) - 1, int(net.broadcast_address) - 1)
    print(f"START={ipaddress.ip_address(s)}\nEND={ipaddress.ip_address(e)}")
