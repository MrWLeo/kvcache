#!/usr/bin/env python2
import argparse
import os
import sys
from time import sleep
sys.path.append(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 '../../utils/'))
import p4runtime_lib.bmv2
import p4runtime_lib.helper

l2_table =  {"00:00:00:00:01:00" : 1,
             "00:00:00:00:01:01" : 2,
             "00:00:00:00:01:02" : 3,
             "00:00:00:00:01:03" : 4,
             "00:00:00:00:01:04" : 5,
             }

node_forward_table = {1 : ("00:00:00:00:01:01", "10.0.1.1", 2),
                      2 : ("00:00:00:00:01:02", "10.0.1.2", 3),
                      3 : ("00:00:00:00:01:03", "10.0.1.3", 4),
                      4 : ("00:00:00:00:01:04", "10.0.1.4", 5)}             

def writeL2ForwardingRules(p4info_helper,sw):
    for (addr,port) in l2_table.items():
        print (addr,port)
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

def writeServerForwardingRules(p4info_helper,sw):
    for (node,(mac,addr,port)) in node_forward_table.items():
        table_entry = p4info_helper.buildTableEntry(
            table_name = "MyIngress.server_routing",
            match_fields={
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

def readTableRules(p4info_helper, sw):
    """
    Reads the table entries from all tables on the switch.

    :param p4info_helper: the P4Info helper
    :param sw: the switch connection
    """
    print '\n----- Reading tables rules for %s -----' % sw.name
    for response in sw.ReadTableEntries():
        for entity in response.entities:
            entry = entity.table_entry
            # TODO For extra credit, you can use the p4info_helper to translate
            #      the IDs the entry to names
            table_name = p4info_helper.get_tables_name(entry.table_id)
            print '%s: ' % table_name,
            for m in entry.match:
                print p4info_helper.get_match_field_name(table_name, m.field_id),
                print '%r' % (p4info_helper.get_match_field_value(m),),
            action = entry.action.action
            action_name = p4info_helper.get_actions_name(action.action_id)
            print '->', action_name,
            for p in action.params:
                print p4info_helper.get_action_param_name(action_name, p.param_id),
                print '%r' % p.value,
            print


def main(p4info_file_path, bmv2_file_path):
    # Instantiate a P4Runtime helper from the p4info file
    p4info_helper = p4runtime_lib.helper.P4InfoHelper(p4info_file_path)
    # Create a switch connection object for s1 and s2;
    s1 = p4runtime_lib.bmv2.Bmv2SwitchConnection(name='s1',address='127.0.0.1:50051',device_id=0,proto_dump_file='logs/s1-p4runtime-requests.txt')
    s1.MasterArbitrationUpdate()

    if (s1.MasterArbitrationUpdate() == None):
        print "S1 Fail to establish the connection"

    s1.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,bmv2_json_file_path=bmv2_file_path)
    writeL2ForwardingRules(p4info_helper,s1)
    writeServerForwardingRules(p4info_helper,s1)
    readTableRules(p4info_helper,s1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='P4Runtime Controller')
    parser.add_argument('--p4info', help='p4info proto in text format from p4c',
                        type=str, action="store", required=False,
                        default='./build/kvcache.p4info')
    parser.add_argument('--bmv2-json', help='BMv2 JSON file from p4c',
                        type=str, action="store", required=False,
                        default='./build/kvcache.json')
    args = parser.parse_args()

    if not os.path.exists(args.p4info):
        parser.print_help()
        print "\np4info file not found: %s\nHave you run 'make'?" % args.p4info
        parser.exit(1)
    if not os.path.exists(args.bmv2_json):
        parser.print_help()
        print "\nBMv2 JSON file not found: %s\nHave you run 'make'?" % args.bmv2_json
        parser.exit(1)

    main(args.p4info, args.bmv2_json)
