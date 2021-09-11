#ifndef SWITCH_H
#define SWITCH_H

#include <vector>
#include <iostream>

#define REG_NUM 128
#define REPLICATE_NUM 4

namespace ns3{
    struct Switch{
            uint32_t index;
            uint32_t version_next;
            uint32_t version[REG_NUM];
            int loc[REG_NUM][REPLICATE_NUM];
            int len[REG_NUM];
    }s[10];
}

#endif