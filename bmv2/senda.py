#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct

from scapy.all import sendp, send, get_if_list, get_if_hwaddr, get_if_addr
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP
from scapy.all import ByteField, ShortField, IntField, BitField


class Apphdr(Packet):
    name = "Apphdr"
    fields_desc = [BitField("id",None,16)]

class Kvcache(Packet):
    name = "Kvcache"
    fields_desc = [ByteField("op", None),
                   IntField("key", None),
                   BitField("version",None,64),
                   ByteField("server_id",None),
                   BitField("chain_id",None,32),
                   BitField("chain_offset",None,32),
                   BitField("chain_length",None,32),
                   BitField("status",None,8),
                   ]

def get_if():
    ifs=get_if_list()
    iface=None # "h1-eth0"
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface

def send_pkt(op,keyhash,msg="1"):
    
    iface = get_if()

    pkt =  Ether(src=get_if_hwaddr(iface))
    pkt = pkt /IP(src=get_if_addr(iface)) / UDP(dport=12345, sport=random.randint(49152,65535)) / Apphdr(id=0x9020) / Kvcache(op=op,key=keyhash,version=1,server_id=1,chain_id=0,chain_length=0,chain_offset=0,status=1)
    #pkt.show2()
    if op==1:
        pkt = pkt/ msg
    sendp(pkt, iface=iface, verbose=False)

def main():
    f = open('data.txt','r')
    r_list = f.read().split('\n')
    r_len = len(r_list)
    for i in range(0,20001):
        request_key = int(r_list[i%r_len])
        op=0
        send_pkt(op,request_key)

if __name__ == '__main__':
    main()
