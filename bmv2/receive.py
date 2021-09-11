#!/usr/bin/env python
import sys
import struct
import os

from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr, get_if_addr
from scapy.all import Packet, IPOption
from scapy.all import ShortField, IntField, LongField, BitField, FieldListField, FieldLenField
from scapy.all import IP, TCP, UDP, Raw, Ether
from scapy.layers.inet import _IPOption_HDR
from send import Kvcache,Apphdr
from items import *

def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface

class IPOption_MRI(IPOption):
    name = "MRI"
    option = 31
    fields_desc = [ _IPOption_HDR,
                    FieldLenField("length", None, fmt="B",
                                  length_of="swids",
                                  adjust=lambda pkt,l:l+4),
                    ShortField("count", 0),
                    FieldListField("swids",
                                   [],
                                   IntField("", 0),
                                   length_from=lambda pkt:pkt.count*4) ]

packet_count=0

def handle_pkt(pkt,iface):
    if Ether in pkt and pkt[Ether].src == get_if_hwaddr(iface):
        return

    if UDP in pkt and pkt[UDP].dport == 12345:
        print "got a packet"
        #pkt.show2()
        global packet_count
        packet_count +=1
        print(packet_count)
        print "-------------------"
    #    hexdump(pkt)
        if Raw in pkt:
            #pkt[Raw].show2()
            #print("fukk")
            opt = ord(pkt[Raw].load[2])
            #print(opt)
            #pkt[Raw].load= pkt[Raw].load[:2]+chr(1) +pkt[Raw].load[3:]
            #pkt[Raw].load[2]=chr(1)
            #pkt[Raw].show2()
            keyhash_chr = pkt[Raw].load[3]+pkt[Raw].load[4]+pkt[Raw].load[5]+pkt[Raw].load[6]
            keyhash = struct.unpack('!i',keyhash_chr)[0]
            #print(keyhash)

            if opt == 0 :
                pkt[Ether].dst = pkt[Ether].src
                pkt[Ether].src = get_if_hwaddr(iface)
                pkt[IP].dst = pkt[IP].src
                pkt[IP].src = get_if_addr(iface)
                pkt[Raw].load= pkt[Raw].load[:2]+chr(3) +pkt[Raw].load[3:]
                msg = cache_items[keyhash]
                pkt = pkt / msg
                sendp(pkt, iface = iface, verbose = False)
                #pkt.show2()
                print "send read reply packet"

            if opt == 1 :
                pkt[Ether].dst = pkt[Ether].src
                pkt[Ether].src = get_if_hwaddr(iface)
                
                server_id = int(get_if_addr(iface)[-1])
                #print(server_id)
                #print(pkt[Raw].load[29:])
                new_val_chr = ""
                for i in pkt[Raw].load[29:]:
                    new_val_chr +=i
                #cache_items[keyhash] = struct.unpack('!i',new_val_chr)[0]
                cache_items[keyhash] = new_val_chr
                pkt[Raw].load= pkt[Raw].load[:2]+chr(2) +pkt[Raw].load[3:15]+ chr(server_id)+pkt[Raw].load[16:28]+chr(1)
                msg = "Write Reply!"
                pkt = pkt / msg
                sendp(pkt, iface = iface, verbose = False)
                #pkt.show2()
                print "send write reply packet"
        #sys.stdout.flush()


def main():
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    print "sniffing on %s" % iface
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x,iface))

if __name__ == '__main__':
    main()