#include <core.p4>
#include <v1model.p4>

/*************************************************************************
 ***********************  H E A D E R S  *********************************
 *************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;
typedef bit<16> udpPort_t;
typedef bit<8>  op_t;
typedef bit<32> keyhash_t;

const bit<16> TYPE_IPV4 = 0x800;
const bit<8> PROTO_UDP = 0x11;
const bit<16> KVCACHE_ID = 0x9020;
const op_t OP_READ = 0x0;
const op_t OP_WRITE = 0x1;
const op_t OP_WRITE_REP = 0x2;
const op_t OP_READ_REP = 0x3;
const bit<32> ITEM_NUM = 32;
const bit<3> MAX_LOCATION = 4;
const bit<8> MAX_SERVER_NUM = 3;

const bit<32> seed1 = 5107;
const bit<32> seed2 = 6011;
const bit<32> seed3 = 1433;
const bit<32> seed4 = 3259;
const bit<32> CM_MAX_LENGTH = 1024;

const bit<8> ON_QUERY = 1;
const bit<8> ON_ROUTING = 2;

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}


header ipv4_t{
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header udp_t {
    udpPort_t   srcPort;
    udpPort_t   dstPort;
    bit<16>     len;
    bit<16>     checksum;
}

header apphdr_t{
    bit<16>    id;
}

header kvcache_t{
    bit<8>     op;
    bit<32>    key;
    bit<64>    ver;
    bit<8>     server_id;
    bit<32>    chain_id;
    bit<32>    chain_offset;
    bit<32>    chain_length;
    bit<8>     status;
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    udp_t        udp;
    apphdr_t     apphdr;
    kvcache_t    kvcache;
}

 
struct metadata {
    /* In our case it is empty */
    bit<32> index;
    bit<32> kv_size;
    bit<64> version;
    bit<64> version_next;
    bit<8>  dst_node;  
    bit<32> chain_hash;
    bit<32> chain_key;
    bit<32> count;
    ip4Addr_t swAddr;
    bit<8>  route_flag;
    bit<8>  pre_check;

    /*
    bit<32> hash1;
    bit<32> hash1_count;
    bit<32> hash2;
    bit<32> hash2_count;
    bit<32> hash3;
    bit<32> hash3_count;
    bit<32> hash4;
    bit<32> hash4_count;
    */
}

/*************************************************************************
 ***********************  R E G I S T E R  *******************************
 *************************************************************************/

// 0-31 : key   32-34 : number of locations  35-42 : location1  43-50 : location2  51-58 : location3 

register<bit<32>>(ITEM_NUM) reg_kv_size;

register<bit<8>>(ITEM_NUM*4) reg_kv_location;

//version for every item in kvtable
register<bit<64>>(1) reg_version_next;

register<bit<64>>(ITEM_NUM) reg_version;

// 0-31 : key  32-47 : value1  48-63 : value2
register<bit<32>>(ITEM_NUM) reg_kv_count;

//
/*
register<bit<32>>(CM_MAX_LENGTH) reg_cm_hash1;
register<bit<32>>(CM_MAX_LENGTH) reg_cm_hash2;
register<bit<32>>(CM_MAX_LENGTH) reg_cm_hash3;
register<bit<32>>(CM_MAX_LENGTH) reg_cm_hash4;
*/
/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {    
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4    : parse_ipv4;
            default      : accept;
        }
    }
    
    state parse_ipv4{
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol){
            PROTO_UDP   : parse_udp;
            default     : accept;
        }
    }

    state parse_udp{
        packet.extract(hdr.udp);
        transition parse_apphdr;
    }

    state parse_apphdr{
        packet.extract(hdr.apphdr);
        transition select(hdr.apphdr.id){
            KVCACHE_ID  : parse_kvcache;
            default     : accept;
        }
    }
    
    state parse_kvcache{
        packet.extract(hdr.kvcache);
        transition accept;
    }

}

/*************************************************************************
 ************   C H E C K S U M    V E R I F I C A T I O N   *************
 *************************************************************************/
control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    
    action count_min(){
        /*
        hash(meta.hash1,HashAlgorithm.crc32,(bit<32>)0,{hdr.kvcache.key,seed1},CM_MAX_LENGTH);
        hash(meta.hash2,HashAlgorithm.crc32,(bit<32>)0,{hdr.kvcache.key,seed2},CM_MAX_LENGTH);
        hash(meta.hash3,HashAlgorithm.crc32,(bit<32>)0,{hdr.kvcache.key,seed3},CM_MAX_LENGTH);
        hash(meta.hash4,HashAlgorithm.crc32,(bit<32>)0,{hdr.kvcache.key,seed4},CM_MAX_LENGTH);

        reg_cm_hash1.read(meta.hash1_count, meta.hash1);
        meta.hash1_count=meta.hash1_count + 1;
        reg_cm_hash1.write(meta.hash1, meta.hash1_count);
        */
    }
    
    action drop() {
        mark_to_drop(standard_metadata);
    }

    // l2 routing
    action l2_forward(egressSpec_t port){
        standard_metadata.egress_spec = port;
    }

    table l2_routing{
        key = {
            hdr.ethernet.dstAddr : exact;
        }
        actions = {
            l2_forward;
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    //ipv4 routing
    action l3_forward(egressSpec_t port){
        standard_metadata.egress_spec = port;
    }

    table l3_routing{
        key = {
            hdr.ipv4.dstAddr : exact;
        }
        actions = {
            l3_forward;
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    action multicast(){
        standard_metadata.mcast_grp = 1;
    }

    action server_forward(macAddr_t macAddr, ip4Addr_t ipv4Addr,egressSpec_t port){
        standard_metadata.egress_spec = port;
        hdr.ethernet.dstAddr = macAddr;
        hdr.ipv4.dstAddr = ipv4Addr;
    }
    
    table server_routing{
        key = {
            meta.chain_hash : exact;
            meta.dst_node : exact ;
        }
        actions = {
            server_forward;
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    action pre_check(){
        meta.pre_check = 1;
    }

    table tab_pre_check{
        key = {
            hdr.kvcache.key : exact;
        }
        actions = {
            pre_check;
            drop;
        }
        default_action = drop();
    }

    action get_cache_index(bit<32> c_index){
        meta.index = c_index;
    }

    table tab_cache_check{
        key = {
            hdr.kvcache.key : exact;
        }
        actions = {
            get_cache_index;
            drop;
        }
        default_action = drop();
    }

    action get_sw_info(ip4Addr_t addr, bit<32> chain_id, bit<32> chain_offset, bit<32> chain_length){
        meta.swAddr = addr;
        hdr.kvcache.chain_id = chain_id;
        hdr.kvcache.chain_offset = chain_offset;
        hdr.kvcache.chain_length = chain_length;
    }

    table tab_get_sw_info{
        key = {
            meta.chain_hash : exact;
        }
        actions = {
            get_sw_info;
            drop;
        }
        default_action = drop();
    }

    action get_node_info(ip4Addr_t addr){
        hdr.ipv4.dstAddr = addr;
    }

    table tab_get_head_info{
        key = {
            meta.chain_hash : exact;
        }
        actions = {
            get_node_info;
            drop;
        }
        default_action = drop();
    }


    table tab_get_tail_info{
        key = {
            meta.chain_hash : exact;
        }
        actions = {
            get_node_info;
            drop;
        }
        default_action = drop();
    }

    //----------------------

    action init_location(){
        hash(meta.dst_node,HashAlgorithm.crc32,(bit<8>)1,{hdr.kvcache.key},MAX_SERVER_NUM-1);
        //meta.dst_node = hdr.kvcache.key & 2;
    }

    action read_handle(){
        bit<32> index = (meta.index-1) * 3 + 1;
        reg_kv_location.read(meta.dst_node, meta.index); 
    }

    action write_handle(){
        //meta.version_next = meta.version_next + 1;
        //hdr.kvcache.ver = meta.version_next;

        reg_version_next.read(meta.version_next,0);
        meta.version_next = meta.version_next + 1;
        reg_version_next.write(0,meta.version_next);

        hdr.kvcache.ver = meta.version_next;

        bit<32> index = (meta.index -1)* 3 +1;
        reg_kv_location.read(meta.dst_node, index); 
    }

    action write_reply_handle_update_version(){
        bit<32> index = (meta.index -1)* 3 +1;

        reg_kv_size.write(meta.index, 1);

        reg_kv_location.write(index,hdr.kvcache.server_id);
        reg_version.write(meta.index,hdr.kvcache.ver);
    }

    action write_reply_handle_update_location(){
        reg_kv_size.read(meta.kv_size, meta.index);
        meta.kv_size = meta.kv_size + 1;
        bit<32> index = (meta.index * 3 -1) + meta.kv_size;
        reg_kv_location.write(index, hdr.kvcache.server_id);
        reg_kv_size.write(meta.index, meta.kv_size);
    }

    action cache_count(){
        reg_kv_count.read(meta.count, meta.index);
        meta.count = meta.count + 1;
        reg_kv_count.write(meta.index, meta.count);
    }

    action get_next_node(ip4Addr_t addr){
        hdr.ipv4.dstAddr = addr;
        hdr.kvcache.chain_offset = hdr.kvcache.chain_offset + 1;
    }

    table tab_get_next_node{
        key = {
            hdr.kvcache.chain_id : exact;
            hdr.kvcache.chain_offset : exact;
        }
        actions = {
            get_next_node;
            drop;
        }
        default_action = drop();
    }
    //----
    apply {
        if (hdr.kvcache.isValid()){
            meta.route_flag = 0;
            meta.chain_hash = hdr.kvcache.key & 1;
            tab_get_sw_info.apply();
            if (hdr.kvcache.status == ON_QUERY){
                if (hdr.kvcache.op == OP_READ) 
                    tab_get_tail_info.apply();
                if (hdr.kvcache.op == OP_WRITE || hdr.kvcache.op == OP_WRITE_REP) 
                    tab_get_head_info.apply();
            
                hdr.kvcache.status = ON_ROUTING;
            }

            if (hdr.ipv4.dstAddr == meta.swAddr){

                meta.route_flag = 1;
                if (tab_cache_check.apply().hit){

                    if (hdr.kvcache.op == OP_READ){
                        read_handle();
                        if (meta.dst_node == 0)
                            init_location();
                    }
                    else if (hdr.kvcache.op == OP_WRITE){
                        write_handle();
                        if (meta.dst_node == 0)
                            init_location();
                        multicast();
                    }
                    else if (hdr.kvcache.op == OP_WRITE_REP){
                        meta.route_flag = 0;
                        reg_version.read(meta.version, meta.index);
                        if (hdr.kvcache.ver > meta.version){
                            write_reply_handle_update_version();
                        }
                        else if (hdr.kvcache.ver == meta.version){
                            write_reply_handle_update_location();
                        }

                        if (hdr.kvcache.chain_offset < hdr.kvcache.chain_length){
                            tab_get_next_node.apply();
                        }
                        else{
                            hdr.ipv4.dstAddr = hdr.ipv4.srcAddr;
                        }
                    }
                }
                else{//cache unhit
                    //meta.dst_node = 1;
                    if (hdr.kvcache.op == OP_WRITE_REP){
                        hdr.ipv4.dstAddr = hdr.ipv4.srcAddr;
                        meta.route_flag = 0;
                    }
                    else{
                        init_location();
                        count_min();
                    }
                }
            }
            if (meta.route_flag == 1) server_routing.apply();
            else l3_routing.apply();
            

        }
        else if (hdr.ethernet.isValid())
            l2_routing.apply();
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    
    action drop() {
        mark_to_drop(standard_metadata);
    }

    apply {
        // Prune multicast packet to ingress port to preventing loop
        if (standard_metadata.egress_port == standard_metadata.ingress_port)
            drop();
        
    }
}

/*************************************************************************
 *************   C H E C K S U M    C O M P U T A T I O N   **************
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 ***********************  D E P A R S E R  *******************************
 *************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.udp);
        packet.emit(hdr.apphdr);
        packet.emit(hdr.kvcache);
    }
}

/*************************************************************************
 ***********************  S W I T T C H **********************************
 *************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
