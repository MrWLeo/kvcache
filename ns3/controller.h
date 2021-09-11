#ifndef CONTROLLER_H
#define CONTROLLER_H

#include <set>
#include <iostream>
#include <map>
#include "ns3/ipv4-address.h"

#define SWITCH_NUM 3
#define CHAIN_NUM 2

namespace ns3{

struct SwitchChain{
    uint16_t id;
    uint16_t offset;
    uint16_t length;
};


#define DATA_CACHE_TYPE std::map<int,int>

#define PRE_TABLE_TYPE  std::set<int>

#define CACHE_TABLE_TYPE std::map<int,int>

#define IP_TABLE_TYPE std::map<int,Ipv4Address>

#define CHAIN_TABLE_TYPE std::map<int,int>
// key - value
std::map<int,int> data_cache; 

//key
std::set<int> pre_table[SWITCH_NUM];

// key - index

int cache_index[SWITCH_NUM];
std::map<int, int> cache_table[SWITCH_NUM];

// nodeid - ip
std::map<int,Ipv4Address> ip_table;//Done

//chain_id+offset - nodeid
std::map<int,int> chain_table;//DONE

//chain_id - switch_id
std::map<int,int> chain_head;//DONE
//chain_id - switch_id
std::map<int,int> chain_tail;//DONE

//chain_id - switch infomation
std::map<int,SwitchChain> sw_info[SWITCH_NUM];//DONE

struct ItemCount{
    int val;
    int key;
}item_count[CHAIN_NUM][10010];

std::vector<int> hot_item;
/*
class controller{
    public:
        controller();
        virtual ~controller();
    private:
        // key - value
        std::map<int,int> data_cache; 
        //key
        std::set<int> pre_table;
        // key - data_location
        std::map<int, std::vector<int> > cache_table;
        // nodeid - ip
        std::map<int,Ipv4Address> ip_table;
        //chain_id+offset - nodeid
        std::map<int,int> chain_table; 
};
*/

}

#endif