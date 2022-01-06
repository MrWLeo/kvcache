control Write_Handle(
        inout header_t hdr,
        inout metadata_t ig_md){

    RegisterAction<bit<32> , INDEX_WIDTH , bit<32> >(reg_global_version) get_global_version_action = {
        void apply(inout bit<32> value, out bit<32> result){
            value = value + 1;
            result = value;
        }
    };

    action get_global_version(){
         hdr.unicache.version = get_global_version_action.execute(0);
    }    


    action get_default_server_index(){
        ig_md.dst_node = 1;
    }    

    apply{
        get_global_version();
        //get_default_server_index();
    }
}


control Write_Reply_Handle(
        inout header_t hdr,
        inout metadata_t ig_md){


    RegisterAction<bit<32> , bit<16> , bit<32> >(reg_cache_version) get_cache_version_action = {
        void apply(inout bit<32> value, out bit<32> result){ 
            if (hdr.unicache.version > value){
                value = hdr.unicache.version;
                result = 0;
            }
            else result = value;
        }
    };

    action get_cache_version(){
        ig_md.version = get_cache_version_action.execute(ig_md.index);
    }

    RegisterAction<bit<8> , INDEX_WIDTH , bit<8> >(reg_cache_index) set_cache_index_action = {
        void apply(inout bit<8> value, out bit<8> result){
            value = hdr.unicache.server_id;
        }
    };

    action set_cache_index(){
        set_cache_index_action.execute(ig_md.l2_index);
    }    

    table tab_set_cache_index{
        actions={
            set_cache_index;
        }
        const default_action = set_cache_index;
    }

    RegisterAction<bit<16> , INDEX_WIDTH , bit<16> >(reg_cache_index_num) set_cache_index_num_action = {
        void apply(inout bit<16> value, out bit<16> result){
            value = 1;
            result = value;
        }
    };

    action set_cache_index_num(){
        ig_md.l2_index_offset =set_cache_index_num_action.execute(ig_md.index);
    }    

    @pragma stage 5
    table tab_set_cache_index_num{
        actions={
            set_cache_index_num;
        }
        const default_action = set_cache_index_num;
    }

    RegisterAction<bit<16> , INDEX_WIDTH , bit<16> >(reg_cache_index_num) add_cache_index_num_action = {
        void apply(inout bit<16> value, out bit<16> result){
            if (value < MAX_PRELICATE_NUM)
                value = value + 1;
            result = value;
        }
    };

    action add_cache_index_num(){
        ig_md.l2_index_offset = add_cache_index_num_action.execute(ig_md.index);
    }

    @pragma stage 5
    table tab_add_cache_index_num{
        actions={
            add_cache_index_num;
        }
        const default_action = add_cache_index_num;
    }

    RegisterAction<bit<16> , INDEX_WIDTH , bit<16> >(reg_cache_index_num) test_cache_index_num_action = {
        void apply(inout bit<16> value, out bit<16> result){
            result = value;
        }
    };

    action test_cache_index_num(){
        ig_md.l2_index_offset = test_cache_index_num_action.execute(ig_md.index);
    }

    apply{
        get_cache_version();
        if (ig_md.version == 0){
            tab_set_cache_index_num.apply();
            ig_md.l2_index = ig_md.l2_index_base + ig_md.l2_index_offset;
            ig_md.l2_update_flag = 1;
        }
         else if (hdr.unicache.version == ig_md.version){
            tab_add_cache_index_num.apply();
            ig_md.l2_index = ig_md.l2_index_base + ig_md.l2_index_offset;
            ig_md.l2_update_flag = 1;
         }
          else {
              test_cache_index_num();
          }
        
        if (ig_md.l2_update_flag == 1){
            set_cache_index();
        }
    }
}
