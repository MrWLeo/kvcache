/*******************************************************************************
 * BAREFOOT NETWORKS CONFIDENTIAL & PROPRIETARY
 *
 * Copyright (c) 2018-2019 Barefoot Networks, Inc.
 * All Rights Reserved.
 *
 * NOTICE: All information contained herein is, and remains the property of
 * Barefoot Networks, Inc. and its suppliers, if any. The intellectual and
 * technical concepts contained herein are proprietary to Barefoot Networks,
 * Inc.
 * and its suppliers and may be covered by U.S. and Foreign Patents, patents in
 * process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material is
 * strictly forbidden unless prior written permission is obtained from
 * Barefoot Networks, Inc.
 *
 * No warranty, explicit or implicit is provided, unless granted under a
 * written agreement with Barefoot Networks, Inc.
 *
 *
 ******************************************************************************/

#include <core.p4>
#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

#include "common/util.p4"
#include "common/headers.p4"
#include "register.p4"
#include "read_handle.p4"
#include "write_handle.p4"
#include "process_data.p4"
// ---------------------------------------------------------------------------
// Ingress parser
// ---------------------------------------------------------------------------
parser SwitchIngressParser(
        packet_in pkt,
        out header_t hdr,
        out metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    TofinoIngressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition parse_ipv4;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            //IP_PROTOCOLS_TCP : parse_tcp;
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dst_port){
            12345 : parse_unicache;
            default: accept;
        }
    }

    // state parse_apphdr{
    //     pkt.extract(hdr.apphdr);
    //     transition select(hdr.apphdr.appid){
    //         APPHDR_UNICACHE : parse_unicache;
    //         default : accept;
    //     }
    // }

    state parse_unicache{
        pkt.extract(hdr.unicache);
        transition accept;
    }
}
// ---------------------------------------------------------------------------
// Ingress Deparser
// ---------------------------------------------------------------------------
control SwitchIngressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    
    Mirror() mirror;
    apply {
        if (ig_dprsr_md.mirror_type == MIRROR_TYPE_I2E) {
            mirror.emit(ig_md.ing_mir_ses);
        }
         pkt.emit(hdr);
    }
}

// ---------------------------------------------------------------------------
// Ingress
// ---------------------------------------------------------------------------


control SwitchIngress(
        inout header_t hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {
    

    action miss() {
        ig_intr_dprsr_md.drop_ctl = 0x1; // Drop packet.
    }

    action l2_forward(PortId_t port){
        ig_intr_tm_md.ucast_egress_port = port;
    }

    table tab_l2_forward{
        key = {
            hdr.ethernet.dst_addr : exact;
        }
        actions = {
            l2_forward;
            miss;
        }
    }

    action l3_forward(PortId_t port){
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table tab_l3_forward{
        key = {
            hdr.ipv4.dst_addr : exact;
        }
        actions = {
            l3_forward;
            miss;
        }
    }

    action unicache_forward(mac_addr_t mac_dst_addr, ipv4_addr_t ipv4_dst_addr, PortId_t port){
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ethernet.dst_addr = mac_dst_addr;
        hdr.ipv4.dst_addr = ipv4_dst_addr;
    }

    table tab_unicache_forward{
        key = {
            ig_md.dst_node : exact;
        }
        actions = {
            unicache_forward;
        } 
    }

    action cache_hit(bit<16> index, bit<16> cache_index, bit<8> status){
        ig_md.index = index;
        ig_md.l2_index_base = cache_index;
        hdr.unicache.status = status;
    }

    action cache_unhit(){
        ig_md.index = UNCACHED;
    }

    table tab_cache_check{
        key = {
            hdr.unicache.key : exact;
        }
        actions = {
            cache_hit;
            cache_unhit;
        }
        const default_action = cache_unhit;
    }

    action get_partition_info(bit<8> sw_role,ipv4_addr_t sw_addr){
        ig_md.sw_role = sw_role;
        ig_md.sw_addr = sw_addr;
    }

    table tab_get_partition_info{
        key = {
            hdr.unicache.key : exact;
        }
        actions = {
            get_partition_info;
        }
    }

    action pre_check(mac_addr_t mac_dst_addr, ipv4_addr_t ipv4_dst_addr, PortId_t port){
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ethernet.dst_addr = mac_dst_addr;
        hdr.ipv4.dst_addr = ipv4_dst_addr;
    }

    table tab_pre_check{
        key = {
            hdr.unicache.key : exact;
        }
        actions = {
            pre_check;
        }
    }


    action set_mirror() {
        ig_intr_dprsr_md.mirror_type = MIRROR_TYPE_I2E;
        ig_md.ing_mir_ses = 1;
    }


    RegisterAction<bit<16>, INDEX_WIDTH, bit<16>>(reg_server_load) update_server_load_action = {
        void apply(inout bit<16> value, out bit<16> result){
            if (hdr.unicache.server_load > LOAD_BOUNDER){
                value = 1;
                result = 1;
            }
            else result = 0;
        }
    };

    action update_server_load(){
        ig_md.server_load = update_server_load_action.execute(0);
    }

    action forward_to_client(){
        hdr.ipv4.dst_addr = hdr.unicache.client_addr;
        //hdr.unicache.op = OP_REP_TO_C;
    }

    RegisterAction<bit<8> , INDEX_WIDTH , bit<8> >(reg_cache_flag) get_cache_flag_action = {
        void apply(inout bit<8> value, out bit<8> result){
            if (hdr.unicache.op == OP_WRITE || hdr.unicache.op == OP_UPDATE_CACHE){
                value = hdr.unicache.op & 1;
            }
            result = value;
        }
    };

    action get_cache_flag(){
         ig_md.cache_flag = get_cache_flag_action.execute(ig_md.index);
    }    

    action get_data_index(bit<16> index){
        ig_md.data_index = index;
    }

    table tab_get_data_index{
        key = {
           ig_md.index : exact;
           hdr.unicache.pkg_offset : exact;
        }
        actions = {
            get_data_index;
        }
    }


    action set_copy_server(mac_addr_t mac_dst_addr, ipv4_addr_t ipv4_dst_addr, PortId_t port){
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ethernet.dst_addr = mac_dst_addr;
        hdr.ipv4.dst_addr = ipv4_dst_addr;
    }

//    @pragma stage 5
    table tab_set_copy_server{
        key = {
            ig_md.copy_server_id : exact;
        } 
        actions = {
            set_copy_server;
        }
    }

    action forward_to_server(){
        hdr.ipv4.dst_addr = hdr.unicache.server_addr;
    }


    RegisterAction<bit<8> , INDEX_WIDTH , bit<8> >(reg_pkt_num) get_pkt_num_action = {
        void apply(inout bit<8> value, out bit<8> result){
            result = value;
        }
    };

    action get_pkt_num(){
         hdr.unicache.pkg_num = get_pkt_num_action.execute(ig_md.index);
    }    


    RegisterAction<bit<8> , INDEX_WIDTH , bit<8> >(reg_pkt_num) set_pkt_num_action = {
        void apply(inout bit<8> value, out bit<8> result){
            value = hdr.unicache.pkg_num;
        }
    };

    action set_pkt_num(){
         set_pkt_num_action.execute(ig_md.index);
    }    


    Read_Handle() read_handle;
    Write_Handle() write_handle;
    Write_Reply_Handle() write_reply_handle;
    Get_Cache_Data() read_data;
    Update_Cache_Data() update_data;

    apply{

        ig_md.l4_forward_flag = 0;

        if (hdr.unicache.isValid()){
            tab_get_partition_info.apply();

            if (hdr.unicache.status == ON_QUERY){
                tab_pre_check.apply();
                hdr.unicache.status = ON_FORWARD;
            }

            if (hdr.ipv4.dst_addr == ig_md.sw_addr){

                tab_cache_check.apply();
                if (ig_md.index != UNCACHED){
                    get_cache_flag();
                    tab_get_data_index.apply();

                    if (hdr.unicache.op == OP_READ && ig_md.cache_flag == 1){
                        get_pkt_num();
                        read_data.apply(hdr,ig_md.data_index);
                        ig_md.forward_dir = 1;
                        hdr.ipv4.src_addr = ig_md.sw_addr;
                        if (hdr.unicache.pkg_offset != hdr.unicache.pkg_num)
                            ig_md.mirrir_flag = 1;
                    }
                    else if (hdr.unicache.op == OP_UPDATE_CACHE){
                        set_pkt_num();
                        update_data.apply(hdr,ig_md.data_index);
                        hdr.unicache.op = OP_ACK;
                        hdr.ipv4.src_addr = ig_md.sw_addr;
                        //forward_to_server();
                    }
                    else if (hdr.unicache.op == OP_WRITE){
                        write_handle.apply(hdr,ig_md);
                    }
                    else if (hdr.unicache.op == OP_WRITE_REP){
                        write_reply_handle.apply(hdr,ig_md);
                        ig_md.forward_dir = 1;
                    }
                    else if (hdr.unicache.op == OP_READ && ig_md.cache_flag == 0){
                        ig_md.l4_forward_flag = 1;
                        read_handle.apply(hdr,ig_md);
                    }
                    else if (hdr.unicache.op == OP_READ_REP){
                        update_server_load();
                        if (ig_md.server_load == 1) {
                            ig_md.mirrir_flag = 1;
                        }
                        ig_md.forward_dir = 1;
                    }
                    else if (hdr.unicache.op == OP_COPY){
                        ig_md.copy_server_id = hash_serverId.get({hdr.unicache.server_id},0,8);
                        tab_set_copy_server.apply();
                    }
                    
                    if (ig_md.forward_dir == 0){
                        forward_to_server();
                    }
                    else{
                        forward_to_client();
                    }
                }
            }
        }

        if (ig_md.mirrir_flag == 1){
            set_mirror();
        }

        if (ig_md.l4_forward_flag == 1){
            tab_unicache_forward.apply();
        }
        else{
            //routing
            tab_l3_forward.apply();
        }
    }
}

// ---------------------------------------------------------------------------
// Egress parser
// ---------------------------------------------------------------------------

parser SwitchEgressParser(
        packet_in pkt,
        out header_t hdr,
        out metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {

    TofinoEgressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, eg_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition parse_ipv4;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            //IP_PROTOCOLS_TCP : parse_tcp;
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dst_port){
            12345 : parse_unicache;
            default: accept;
        }
    }

    // state parse_apphdr{
    //     pkt.extract(hdr.apphdr);
    //     transition select(hdr.apphdr.appid){
    //         APPHDR_UNICACHE : parse_unicache;
    //         default : accept;
    //     }
    // }

    state parse_unicache{
        pkt.extract(hdr.unicache);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Egress Deparser
// ---------------------------------------------------------------------------
control SwitchEgressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {

    apply {
        pkt.emit(hdr);
    }
}

// ---------------------------------------------------------------------------
// Switch Egress MAU
// ---------------------------------------------------------------------------
control SwitchEgress(
        inout header_t hdr,
        inout metadata_t eg_md,
        in    egress_intrinsic_metadata_t                 eg_intr_md,
        in    egress_intrinsic_metadata_from_parser_t     eg_prsr_md,
        inout egress_intrinsic_metadata_for_deparser_t    eg_dprsr_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_oport_md) {


    apply {
        if (eg_intr_md.egress_port == RECIR_PORT){//recirculate port
            if (hdr.unicache.op == OP_READ){
                 hdr.unicache.pkg_offset = hdr.unicache.pkg_offset + 1;
            }
            else if (hdr.unicache.op == OP_UPDATE_CACHE){
                hdr.unicache.op = OP_ACK;
                hdr.ipv4.dst_addr = hdr.unicache.server_addr;
            }
            else if (hdr.unicache.op == OP_READ_REP){
                hdr.unicache.op = OP_COPY;
            }
            
        }
    }
}

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         SwitchEgressParser(),
         SwitchEgress(),
         SwitchEgressDeparser()) pipe;


// Pipeline(SwitchIngressParser(),
//          SwitchIngress(),
//          SwitchIngressDeparser(),
//          EmptyEgressParser<header_t, metadata_t>(),
//          EmptyEgress<header_t, metadata_t>(),
//          EmptyEgressDeparser<header_t, metadata_t>()) pipe;

Switch(pipe) main;
