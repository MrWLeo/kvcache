l3_table = {
    "10.0.3.3" : 1,
    "10.0.3.4" : 2,
    "10.0.2.1" : 3,
    "10.0.2.2" : 3,
    "10.0.1.0" : 3,
    "192.168.100.1" : 3,
    "192.168.100.2" : 3,
}

l2_table =  {
    "00:00:00:00:03:03" : 1,
    "00:00:00:00:03:04" : 2,
}

node_forward_table = {
    (1,1) : ("00:00:00:00:03:03", "10.0.3.3", 1),
    (1,2) : ("00:00:00:00:03:04", "10.0.3.4", 2)
}     

cache_table = {
    15 : 1,
    31 : 2
}

switch_table = {
    1 : ("192.168.100.3", 1, 2, 1)
}

head_table = {
    0 : "192.168.100.2",
    1 : "192.168.100.3",
}

tail_table = {
    0 : "192.168.100.1",
    1 : "192.168.100.1",
}

next_node_table = {
    (1,1) : "192.168.100.1"
}