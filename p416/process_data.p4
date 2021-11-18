#define REGISTER_GET(i) \
    Register<bit<32>, INDEX_WIDTH>(16) reg_data_1_##i; \
    Register<bit<32>, INDEX_WIDTH>(16) reg_data_2_##i; \
    Register<bit<32>, INDEX_WIDTH>(16) reg_data_3_##i; \
    Register<bit<32>, INDEX_WIDTH>(16) reg_data_4_##i; \

#define READ_DATA_REG_SLICE(i,j) \
    RegisterAction<bit<32> , INDEX_WIDTH , bit<32> >(reg_data_##i##_##j ) read_data_##i##_##j##_action = { \
        void apply(inout bit<32> value, out bit<32> result){ \
            result = value; \
        } \
    }; \

#define READ_DATA_REG(i) \
    READ_DATA_REG_SLICE(1,i) \
    READ_DATA_REG_SLICE(2,i) \  
    READ_DATA_REG_SLICE(3,i) \
    READ_DATA_REG_SLICE(4,i) \

#define WRITE_DATA_REG_SLICE(i,j,k) \
    RegisterAction<bit<32> , INDEX_WIDTH , bit<32> >(reg_data_##i##_##j ) write_data_##i##_##j##_action = { \
        void apply(inout bit<32> value, out bit<32> result){ \
            value = k; \
        } \
    }; \


#define WRITE_DATA_REG(i) \
    WRITE_DATA_REG_SLICE(1,i,hdr.unicache.value1_##i) \
    WRITE_DATA_REG_SLICE(2,i,hdr.unicache.value2_##i) \
    WRITE_DATA_REG_SLICE(3,i,hdr.unicache.value3_##i) \
    WRITE_DATA_REG_SLICE(4,i,hdr.unicache.value4_##i) \


#define READ_DATA_ACTION(i) \
    action read_data_1_##i (INDEX_WIDTH j){ \
        hdr.unicache.value1_##i = read_data_1_##i##_action.execute(j); \
    } \
    action read_data_2_##i (INDEX_WIDTH j){ \
        hdr.unicache.value2_##i = read_data_2_##i##_action.execute(j); \
    } \
    action read_data_3_##i (INDEX_WIDTH j){ \
        hdr.unicache.value3_##i = read_data_3_##i##_action.execute(j); \
    } \
    action read_data_4_##i (INDEX_WIDTH j){ \
        hdr.unicache.value4_##i = read_data_4_##i##_action.execute(j); \
    } \

#define WRITE_DATA_ACTION(i) \
    action write_data_1_##i (INDEX_WIDTH j){ \
        write_data_1_##i##_action.execute(j); \
    } \
    action write_data_2_##i (INDEX_WIDTH j){ \
        write_data_2_##i##_action.execute(j); \
    } \
    action write_data_3_##i (INDEX_WIDTH j){ \
        write_data_3_##i##_action.execute(j); \
    } \
    action write_data_4_##i (INDEX_WIDTH j){ \
        write_data_4_##i##_action.execute(j); \
    } \

REGISTER_GET(1)
REGISTER_GET(2)
REGISTER_GET(3)
REGISTER_GET(4)
// REGISTER_GET(5)
// REGISTER_GET(6)
// REGISTER_GET(7)
// REGISTER_GET(8)

#define GET_DATA(i) \
    READ_DATA_REG(i) \
    READ_DATA_ACTION(i) \

#define WRITE_DATA(i) \
    WRITE_DATA_REG(i) \
    WRITE_DATA_ACTION(i) \

#define READ_ACTION(i,index) \
    read_data_1_##i(index); \
    read_data_2_##i(index); \
    read_data_3_##i(index); \
    read_data_4_##i(index); \

#define WRITE_ACTION(i,index) \
    write_data_1_##i(index); \
    write_data_2_##i(index); \
    write_data_3_##i(index); \
    write_data_4_##i(index); \

control Get_Cache_Data(
    inout header_t hdr,
    in bit<16> data_index){
    
    GET_DATA(1)
    GET_DATA(2)
    GET_DATA(3)
    GET_DATA(4)
    // GET_DATA(5)
    // GET_DATA(6)
    // GET_DATA(7)
    // GET_DATA(8)

    apply{
        READ_ACTION(1,data_index)
        READ_ACTION(2,data_index)
        READ_ACTION(3,data_index)
        READ_ACTION(4,data_index)
        //READ_ACTION(5,ig_md.data_index)
        //READ_ACTION(6,ig_md.data_index)
        //READ_ACTION(7,ig_md.data_index)
        //READ_ACTION(8,ig_md.data_index)
    }
}

control Update_Cache_Data(
    inout header_t hdr,
    in bit<16> data_index){
    
    WRITE_DATA(1)
    WRITE_DATA(2)
    WRITE_DATA(3)
    WRITE_DATA(4)
//    WRITE_DATA(5)
//    WRITE_DATA(6)
//    WRITE_DATA(7)
//    WRITE_DATA(8)

    apply{
        WRITE_ACTION(1,data_index)
        WRITE_ACTION(2,data_index)
        WRITE_ACTION(3,data_index)
        WRITE_ACTION(4,data_index)
        //WRITE_ACTION(1,1)
        //WRITE_ACTION(2,1)
        //WRITE_ACTION(3,1)
        //WRITE_ACTION(4,1)
    }
}
