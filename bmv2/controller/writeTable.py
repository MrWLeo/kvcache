def writeL3ForwardingRules(p4info_helper,sw,tb):
    for (addr,port) in tb.items():
        #print (addr,port)
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.l3_routing",
            match_fields={
                "hdr.ipv4.dstAddr":addr
            },
            action_name="MyIngress.l3_forward",
            action_params={
                "port":port
            }
        )
        sw.WriteTableEntry(table_entry)

def writeL2ForwardingRules(p4info_helper,sw,tb):
    for (addr,port) in tb.items():
        #print (addr,port)
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.l2_routing",
            match_fields={
                "hdr.ethernet.dstAddr":addr
            },
            action_name="MyIngress.l2_forward",
            action_params={
                "port":port
            }
        )
        sw.WriteTableEntry(table_entry)

def writeServerForwardingRules(p4info_helper,sw,tb):
    for ((chain_hash,node),(mac,addr,port)) in tb.items():
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.server_routing",
            match_fields={
                "meta.chain_hash" : chain_hash,
                "meta.dst_node" : node
            },
            action_name="MyIngress.server_forward",
            action_params={
                "macAddr"  : mac,
                "ipv4Addr" : addr,
                "port"     : port
            }
        )
        sw.WriteTableEntry(table_entry)

def writeCacheTable(p4info_helper,sw,tb):
    for (key,index) in tb.items():
        #print (addr,port)
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.tab_cache_check",
            match_fields={
                "hdr.kvcache.key": key
            },
            action_name="MyIngress.get_cache_index",
            action_params={
                "c_index": index
            }
        )
        sw.WriteTableEntry(table_entry)


def writeSwTable(p4info_helper,sw,tb):
    for (key,(addr,chain_id,chain_length,chain_offset)) in tb.items():
        #print (addr,port)
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.tab_get_sw_info",
            match_fields={
                "meta.chain_hash": key
            },
            action_name="MyIngress.get_sw_info",
            action_params={
                "addr": addr,
                "chain_id": chain_id,
                "chain_offset": chain_offset,
                "chain_length": chain_length
            }
        )
        sw.WriteTableEntry(table_entry)

def writeHeadTable(p4info_helper,sw,tb):
    for (key,addr) in tb.items():
        #print (addr,port)
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.tab_get_head_info",
            match_fields={
                "meta.chain_hash": key
            },
            action_name="MyIngress.get_node_info",
            action_params={
                "addr": addr
            }
        )
        sw.WriteTableEntry(table_entry)


def writeTailTable(p4info_helper,sw,tb):
    for (key,addr) in tb.items():
        #print (addr,port)
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.tab_get_tail_info",
            match_fields={
                "meta.chain_hash": key
            },
            action_name="MyIngress.get_node_info",
            action_params={
                "addr": addr
            }
        )
        sw.WriteTableEntry(table_entry)

def writeNextNodeTable(p4info_helper,sw,tb):
    for ((chain_id,chain_offset),addr) in tb.items():
        #print (addr,port)
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.tab_get_next_node",
            match_fields={
                "hdr.kvcache.chain_id": chain_id,
                "hdr.kvcache.chain_offset": chain_offset
            },
            action_name="MyIngress.get_next_node",
            action_params={
                "addr": addr
            }
        )
        sw.WriteTableEntry(table_entry)

def writeMultiCastTable(p4info_helper,sw,tb,group_id):
    mc_entry = p4info_helper.buildMulticastGroupEntry(
        multicast_group_id = group_id,
        replicas = tb
    )
    sw.WritePREEntry(mc_entry)
