#include "register.p4"
#include "process_data.p4"

control Read_Handle(
        inout header_t hdr,
        inout metadata_t ig_md){

    RegisterAction<bit<8> , INDEX_WIDTH , bit<8> >(reg_cache_flag) get_cache_flag_action = {
        void apply(inout bit<8> value, out bit<8> result){
            result = value;
        }
    };

    action get_cache_flag(){
         ig_md.cache_flag = get_cache_flag_action.execute(ig_md.index);
    }    

    RegisterAction<bit<16> , INDEX_WIDTH , bit<16> >(reg_cache_index_num) get_cache_index_num_action = {
        void apply(inout bit<16> value, out bit<16> result){
            result = value;
        }
    };

    action get_cache_index_num(){
        ig_md.l2_index_offset = get_cache_index_num_action.execute(ig_md.index);
    }    

    RegisterAction<bit<8> , INDEX_WIDTH , bit<8> >(reg_cache_index) get_cache_index_action = {
        void apply(inout bit<8> value, out bit<8> result){
            result = value;
        }
    };

    action set_forward_server(){
        ig_md.dst_node = get_cache_index_action.execute(ig_md.l2_index);
    }    
    

    Get_Cache_Data() rcd;
    

    apply{
         get_cache_flag();
        // if (ig_md.cache_flag == 0){
        //     get_cache_index_num();
        //     //ig_md.l2_index = hash_random.get({hdr.unicache.key},ig_md.l2_index_base,ig_md.l2_index_offset);
        //     ig_md.l2_index = ig_md.l2_index_base + ig_md.l2_index_offset;
        //     set_forward_server();
        // }
        // else {
        //     //rcd.apply(hdr,fku);
        //     if (hdr.unicache.pkg_offset < 4){
        //         ig_md.mirrir_flag = 1;
        //     }
        // }
        if (ig_md.cache_flag == 1){
            rcd.apply(hdr,ig_md.data_index);
        }
        else{
            get_cache_index_num();
            //ig_md.l2_index = ig_md.l2_index_base + ig_md.l2_index_offset;
        }
    }
}

control Read_Reply_Handle(
        inout header_t hdr,
        inout metadata_t ig_md){

    RegisterAction<bit<8> , INDEX_WIDTH , bit<8> >(reg_cache_flag) set_cache_flag_action = {
        void apply(inout bit<8> value, out bit<8> result){
            value = 1;
        }
    };

    action set_cache_flag(){
         ig_md.cache_flag = set_cache_flag_action.execute(ig_md.index);
    }    

    Update_Cache_Data() u;

    apply{
        
        set_cache_flag();
        if (ig_md.cache_flag == 1){
            u.apply(hdr,ig_md.data_index);
        }
        //ig_md.mirrir_flag = 1;
            
    }
}
