
control Read_Handle(
        inout header_t hdr,
        inout metadata_t ig_md){

    RegisterAction<bit<16> , INDEX_WIDTH , bit<16> >(reg_cache_index_num) get_cache_index_num_action = {
        void apply(inout bit<16> value, out bit<16> result){
            result = value;
        }
    };

    action get_cache_index_num(){
        ig_md.l2_index_offset = get_cache_index_num_action.execute(ig_md.index);
    }    

    @pragma stage 5
    table tab_get_cache_index_num{
        actions={
            get_cache_index_num;
        }
        const default_action = get_cache_index_num;
    }

    RegisterAction<bit<16> , INDEX_WIDTH , bit<16> >(reg_rand_robin) get_rand_robin_action = {
        void apply(inout bit<16> value, out bit<16> result){
            if (value < ig_md.l2_index_offset)
                value = value + 1;
            else value = 1;
            result = value;
        }
    };

    action get_rand_robin(){
        ig_md.l2_index = ig_md.l2_index_base + get_rand_robin_action.execute(ig_md.index);
    }    

    table tab_get_rand_robin{
        actions={
            get_rand_robin;
        }
        const default_action = get_rand_robin;
    }

    action get_hash(){
        ig_md.l2_index = hash_random.get({hdr.unicache.key},ig_md.l2_index_base,ig_md.l2_index_offset);
    }

    @pragma stage 6
    table tab_get_hash{
        actions={
            get_hash;
        }
        const default_action = get_hash;
    }

    action no_action(){
    
    }
    @pragma stage 6
    table tab_get_no_action{
        actions={
            no_action;
        }
        const default_action = no_action;
    }  
    RegisterAction<bit<8> , INDEX_WIDTH , bit<8> >(reg_cache_index) get_cache_index_action = {
        void apply(inout bit<8> value, out bit<8> result){
            result = value;
        }
    };

    action set_forward_server(){
        ig_md.dst_node = get_cache_index_action.execute(ig_md.l2_index);
    }    
    
    @pragma stage 7
    table tab_set_forward_server{
        actions={
            set_forward_server;
        }
        const default_action = set_forward_server;
    }

    apply{
        tab_get_cache_index_num.apply();
        //tab_get_hash.apply();
        //tab_get_no_action.apply();
        if (ig_md.sample == 0){
            tab_get_rand_robin.apply();
        }
        else{
            tab_get_hash.apply();
        }
        tab_set_forward_server.apply();
        if (ig_md.l2_index_offset == 0) 
            ig_md.l4_forward_flag = 0;
    }
}
