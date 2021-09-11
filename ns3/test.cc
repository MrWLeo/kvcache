#include "ns3/ptr.h"
#include "ns3/packet.h"
#include <iostream>
#include "myheader.h"
#include "controller.h"
#include "switch.h"

#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/applications-module.h"
#include "ns3/traffic-control-module.h"
#include "ns3/ipv4-header.h"

using namespace ns3;

#define SERVER_NUM 5

std::vector<Ipv4InterfaceContainer> ipC1T1;
std::vector<Ipv4InterfaceContainer> ipS1T2;
std::vector<Ipv4InterfaceContainer> ipS2T3;

std::vector< std::vector<int> > chain;
int packet_count = 0;
int t1 = 0;

void SplitString( std::string& s, std::vector<std::string>& v, std::string& c)
{
     int l = s.find('(')+1,r=s.find(')');
     std::string new_s = s.substr(l,r-l); 
     
     std::string::size_type pos1, pos2;
     pos2 = new_s.find(c);
     pos1 = 0;
     while(std::string::npos != pos2)
     {
         v.push_back(new_s.substr(pos1, pos2-pos1));

         pos1 = pos2 + c.size();
         pos2 = new_s.find(c, pos1);
     }
     if(pos1 != new_s.length())
         v.push_back(new_s.substr(pos1));
}


Ptr<Packet> add_packet(){
  // Enable the packet printing through Packet::Print command.
  Packet::EnablePrinting ();

  // instantiate a header.
  MyHeader sourceHeader;
  sourceHeader.SetData2 (1,2,3,4);

  Ipv4Header ipv4header ;
  ipv4header.SetTtl(32);
  
  // instantiate a packet
  Ptr<Packet> p = Create<Packet> ();
  p->AddHeader (ipv4header);
  // and store my header into the packet.
  p->AddHeader (sourceHeader);
  
  
  return p;
}

Ptr<Packet> set_header_packet(MyHeader data){
    Packet::EnablePrinting();
    Ptr<Packet> p = Create<Packet>();
    p->AddHeader(data);
    return p;
}

Ptr<Packet> set_packet(Ipv4Header ipv4,MyHeader header){
    Packet::EnablePrinting();
    Ptr<Packet> p =Create<Packet>();
    p->AddHeader(ipv4);
    p->AddHeader(header);
    //NS_LOG_UNCOND(ipv4.GetSource());
    return p;
}

void SendPacketEvent(Ptr<Socket> socket,Ptr<Packet> packet){
    //NS_LOG_UNCOND("SEND");
    //packet->Print(std::cout);

    socket->Send (packet);
}

void SendPacket(Ptr<Socket> s,Ptr<Packet> p,Ipv4Address addr){
     InetSocketAddress remote = InetSocketAddress (addr, 4477);
     s->Connect (remote);

     Simulator::Schedule(Seconds(0),&SendPacketEvent,s,p);
}


void ClientReceivePacket (Ptr<Socket> socket)
{
  int nodeid = socket->GetNode()->GetId();
  //NS_LOG_UNCOND ("Received one packet!");
  Ptr<Packet> packet = socket->Recv ();
  
  MyHeader hdrkv;
  Ipv4Header ipv4;
  packet->RemoveHeader(hdrkv);
  packet->PeekHeader(ipv4);
  hdr_kv kv = hdrkv.GetData();

//   std::cout<<"Client "<<nodeid<<" Receive From: "<<ipv4.GetSource()<<"  OP: ";
//   if (kv.op==OP_READ_REPLY) std::cout<<"read  Value: "<<kv.value<<"\n";
//   else std::cout<<"write reply  ModifyValue: " << kv.value<<"\n";

  packet_count++;
  if (! (packet_count % 100)){
      std::cout<<"Packets count:"<<packet_count<<" ;Now time:"<<Simulator::Now().GetMicroSeconds()<<"\n";
  }

}

void ServerReceivePacket (Ptr<Socket> socket)
{
  int nodeid = socket->GetNode()->GetId();
  //NS_LOG_UNCOND("Get a request!");
  //Address sendaddr;
  Ptr<Packet> packet = socket->Recv();
  //InetSocketAddress srcaddr = InetSocketAddress::ConvertFrom (sendaddr);
  
  MyHeader hdrkv;
  Ipv4Header ipv4;

  packet->RemoveHeader(hdrkv);
  packet->PeekHeader(ipv4);
  Ipv4Address clinetaddr = ipv4.GetSource();
  hdr_kv kv = hdrkv.GetData();
  //NS_LOG_UNCOND(clinetaddr);
  
  ipv4.SetSource(ip_table.find(nodeid)->second);
  ipv4.SetDestination(clinetaddr);

  DATA_CACHE_TYPE::iterator iter;

  if (kv.op == OP_READ){
    iter = data_cache.find(kv.key);
    kv.value = iter->second;
    kv.op = OP_READ_REPLY;
    //read reply
    //srcaddr need to be corrected
    hdrkv.SetData(kv);
    SendPacket(socket,set_packet(ipv4,hdrkv),clinetaddr);
    
  }
  else if (kv.op == OP_WRITE || kv.op == OP_WRITE_UNCACHE){
    data_cache.erase(kv.key);
    data_cache.insert(std::pair<int,int>(kv.key,kv.value));
    //std::cout<<"Modify: "<<kv.key<<"  "<<kv.value<<"\n";
    kv.server_id = nodeid;
    kv.op = OP_WRITE_REPLY;
    
    if (kv.op == OP_WRITE){
    //write reply     
        int chain_key = kv.chain_id * 10000 + 1;
        CHAIN_TABLE_TYPE::iterator iteri = chain_table.find(chain_key);
        IP_TABLE_TYPE::iterator iterj = ip_table.find(iteri->second);
        
        //ipv4.SetDestination(clinetaddr);
        hdrkv.SetData(kv);
        SendPacket(socket,set_packet(ipv4,hdrkv),iterj->second);
    }
    else{
        hdrkv.SetData(kv);
        SendPacket(socket,set_packet(ipv4,hdrkv),clinetaddr);
    }
  }

}

int get_hash(int chain_id,int key){
    int base = 13 + chain_id * 10;
    return base + (key%5);
}
//

//
void SwitchReceivePacket (Ptr<Socket> socket)
{
  int nodeid = socket->GetNode()->GetId();
  
  Ptr<Packet> packet = socket->Recv ();

  Ipv4Header ipv4hd;
  MyHeader hdrkv;
  
  //packet->PeekHeader(hdrkv);
  packet->RemoveHeader(hdrkv);
  packet->PeekHeader(ipv4hd);

  //NS_LOG_UNCOND(packet->ToString());
  //NS_LOG_UNCOND(ipv4hd.GetSource());
  //NS_LOG_UNCOND(ipv4hd.GetDestination());
  hdr_kv kv = hdrkv.GetData();
  
  int index;
  int chain_hash = kv.key % 2;

  if (kv.status == ON_QUERY){
      int dstnode = 0;
      if (kv.op==OP_READ){
          dstnode = chain_tail.find(chain_hash)->second;
      }
      else if (kv.op==OP_WRITE||kv.op==OP_WRITE_REPLY){
          dstnode = chain_head.find(chain_hash)->second;
          
      }
      kv.status = ON_ROUTING;
      hdrkv.SetData(kv);
      
      if (dstnode != nodeid) {
        SendPacket(socket,set_packet(ipv4hd,hdrkv),ip_table.find(dstnode)->second);
        return;
      }
  }
  
  if (pre_table[nodeid].count(kv.key)){
      //NS_LOG_UNCOND("Pre_Table!");
      SwitchChain swchain = sw_info[nodeid].find(chain_hash)->second;
      kv.chain_id = swchain.id;
      kv.chain_offset = swchain.offset;
      kv.chain_length = swchain.length;

      //std::cout<<"Switch:"<<nodeid<<" "<<swchain.id<<" "<<swchain.offset<<" "<<swchain.length<<"\n";
      
      if (cache_table[nodeid].count(kv.key)){
          //NS_LOG_UNCOND("Cache hit!");
          s[nodeid].index = cache_table[nodeid].find(kv.key)->second;          
          index = s[nodeid].index;
          if (kv.op==OP_READ){
              //TODO len=0 set default loc
              if (s[nodeid].len[index]==0){
                  s[nodeid].len[index]=1;
                  s[nodeid].loc[index][0]=get_hash(chain_hash,kv.key);
                  item_count[chain_hash][kv.key].val++;
              }
              int dstnode = s[nodeid].loc[index][0];
              //NS_LOG_UNCOND(dstnode);
              Ipv4Address dstaddr = ip_table.find(dstnode)->second;
              //NS_LOG_UNCOND(dstaddr);
              hdrkv.SetData(kv);
              SendPacket(socket,set_packet(ipv4hd,hdrkv),dstaddr);
          }
          else if (kv.op==OP_WRITE){
              if (s[nodeid].len[index]==0){
                  s[nodeid].len[index]=1;
                  s[nodeid].loc[index][0]=get_hash(chain_hash,kv.key);
              }
              int dstnode = s[nodeid].loc[index][0];

              Ipv4Address dstaddr = ip_table.find(dstnode)->second;
              kv.version = ++ s[nodeid].version_next;
              
              item_count[chain_hash][kv.key].val++;
              hdrkv.SetData(kv);
              //TODO: send to multi servers
              SendPacket(socket,set_packet(ipv4hd,hdrkv),dstaddr);
          }
          else if (kv.op==OP_WRITE_REPLY){
              if (kv.version > s[nodeid].version[index]){
                  s[nodeid].version[index] = kv.version;
                  s[nodeid].len[index] = 1;
                  s[nodeid].loc[index][0] = kv.server_id;
              }
              else if (kv.version == s[nodeid].version[index]){
                  s[nodeid].len[index]++;
                  s[nodeid].loc[index][s[nodeid].len[index]] = kv.server_id;
              }
              if(kv.chain_offset < kv.chain_length){
                kv.chain_offset++;
                int chain_key = kv.chain_id * 10000 + kv.chain_offset;
                CHAIN_TABLE_TYPE::iterator iter = chain_table.find(chain_key);
                IP_TABLE_TYPE::iterator iterj = ip_table.find(iter->second);
                hdrkv.SetData(kv);
                SendPacket(socket,set_packet(ipv4hd,hdrkv),iterj->second);
              }
              else{
                //Reply to Client
                hdrkv.SetData(kv);
                SendPacket(socket,set_packet(ipv4hd,hdrkv),ipv4hd.GetDestination());
              }
          }

      }
      //key not in switch but in chain
      else{
          if (kv.op == OP_READ){
              //NS_LOG_UNCOND("???");
              kv.chain_offset--;
              int chain_key = kv.chain_id * 10000 + kv.chain_offset;
              CHAIN_TABLE_TYPE::iterator iter = chain_table.find(chain_key);
              IP_TABLE_TYPE::iterator iterj = ip_table.find(iter->second);
              hdrkv.SetData(kv);
              SendPacket(socket,set_packet(ipv4hd,hdrkv),iterj->second);
          }
          else{
              if (kv.chain_offset == kv.chain_length){
                hdrkv.SetData(kv);
                SendPacket(socket,set_packet(ipv4hd,hdrkv),ipv4hd.GetDestination());
              }
              else{
                kv.chain_offset++;
                int chain_key = kv.chain_id * 10000 + kv.chain_offset;
                CHAIN_TABLE_TYPE::iterator iter = chain_table.find(chain_key);
                IP_TABLE_TYPE::iterator iterj = ip_table.find(iter->second);
                hdrkv.SetData(kv);
                SendPacket(socket,set_packet(ipv4hd,hdrkv),iterj->second);
              }
          }
      }
  }
  //set uncache data;
  else{
      int dstnode = get_hash(chain_hash,kv.key);//TODO:hash
      //NS_LOG_UNCOND("MARK");
      kv.op = OP_WRITE_UNCACHE;
      hdrkv.SetData(kv);
      SendPacket(socket,set_packet(ipv4hd,hdrkv),ip_table.find(dstnode)->second);
  }

}

void Install_pre(int node,int n){
    for (int i=0;i<n;i++)
        pre_table[node].insert(hot_item[i]);
}

void Install_cache(int node,int n, double p){
    for (int i=0;i<n*p;i++){
        int k = cache_index[node]++;
        cache_table[node].insert(std::pair<int,int>(hot_item[i],k));
    }
}

bool cmp(ItemCount a,ItemCount b){
  return a.val>b.val;
}

void UpdateHotItem(){
  for (int i=0;i<CHAIN_NUM;i++){
      std::sort(item_count[i],item_count[i]+10000,cmp);
      int len = chain[i].size();
      double p = 1;
      for (int j=0;j<len;j++){
          Install_pre(chain[i][j],10);
          Install_cache(chain[i][j],10,p);
          p=p*0.5;
      }
  }
  memset(item_count,0,sizeof(item_count));
}

void Data_Init(){
  // Init data
  for (int i=0;i<10000;i++){
      data_cache.insert(std::pair<int,int>(i,i));
  }  
}


void Switch_Init(){

  Data_Init();  
  //init chain

  std::fstream f1;
  f1.open("/Users/wangli/NS3/ns-allinone-3.34/ns-3.34/scratch/chain.txt",std::ios::in);
  
  int len,node;
  for (int i=0;i<=1;i++){
      f1>>len;
      //NS_LOG_UNCOND(len);
      std::vector<int> ck;
      for (int j=0;j<len;j++){
          f1>>node;
          //NS_LOG_UNCOND(node);
          ck.push_back(node);
          int chain_index = (i) *10000 + j + 1;
          chain_table.insert(std::pair<int,int>(chain_index,node));
          SwitchChain sw;
          sw.id = i ;sw.offset=j+1; sw.length=len;
          sw_info[node].insert(std::pair<int,SwitchChain>(i,sw));
      }
      chain.push_back(ck);
      chain_head.insert(std::pair<int,int>(i,chain[i][0]));
      chain_tail.insert(std::pair<int,int>(i,chain[i][len-1]));
   }
  f1.close();
  
  for (int i=0;i<100;i++){
      hot_item.push_back(i);
  }

  for (int i=0;i<=1;i++){
      int len = chain[i].size();
      double p = 1;
      for (int j=0;j<len;j++){
          Install_pre(chain[i][j],10);
          Install_cache(chain[i][j],10,p);
          p=p*0.5;
      }
  }
}


static void TestSendPacket (Ptr<Socket> socket, Ptr<Packet> packet, uint32_t f,
                        uint32_t pktCount, Time pktInterval )
{
  if (pktCount > f)
    {
      int k = socket->Send (packet);
      t1++;
      Simulator::Schedule (pktInterval, &TestSendPacket, 
                           socket, packet,f+1,pktCount , pktInterval);
    }
  else
    {
      socket->Close ();
    }
}



int main (int argc, char *argv[])
{

  CommandLine cmd (__FILE__);
  cmd.Parse (argc, argv);

  Ptr<Node> T1 = CreateObject<Node>();
  Ptr<Node> T2 = CreateObject<Node>();
  Ptr<Node> T3 = CreateObject<Node>();

  NodeContainer C1,S1,S2;
  C1.Create(10);
  S1.Create(10);
  S2.Create(10);
  

  PointToPointHelper p2pST;
  p2pST.SetDeviceAttribute ("DataRate", StringValue ("1Gbps"));
  p2pST.SetChannelAttribute ("Delay", StringValue ("10ms"));

  PointToPointHelper p2pTT;
  p2pTT.SetDeviceAttribute ("DataRate", StringValue ("10Gbps"));
  p2pTT.SetChannelAttribute ("Delay", StringValue ("10ms"));
  
  
  std::vector<NetDeviceContainer> C1T1;
  C1T1.reserve (10);
  std::vector<NetDeviceContainer> S1T2;
  S1T2.reserve (10);
  std::vector<NetDeviceContainer> S2T3;
  S2T3.reserve (10);

  NetDeviceContainer T1T2 = p2pTT.Install (T1, T2);
  NetDeviceContainer T1T3 = p2pTT.Install (T1, T3);
  for (int i=0;i<10;i++){
      C1T1.push_back(p2pST.Install( T1, C1.Get(i) ));
  }
  for (int i=0;i<10;i++){
      S1T2.push_back(p2pST.Install( T2, S1.Get(i) ));
  }
  for (int i=0;i<10;i++){
      S2T3.push_back(p2pST.Install( T3, S2.Get(i) ));
  }
  InternetStackHelper stack;
  stack.InstallAll ();
  

  Ipv4AddressHelper address;
//   std::vector<Ipv4InterfaceContainer> ipC1T1;
   ipC1T1.reserve (10);
//   std::vector<Ipv4InterfaceContainer> ipS1T2;
   ipS1T2.reserve (10);
//   std::vector<Ipv4InterfaceContainer> ipS2T3;
   ipS2T3.reserve (10);

  address.SetBase ("192.168.1.0", "255.255.255.0");
  Ipv4InterfaceContainer ipT1T2 = address.Assign (T1T2);
  address.SetBase ("192.169.1.0", "255.255.255.0");
  Ipv4InterfaceContainer ipT1T3 = address.Assign (T1T3);

  address.SetBase ("10.1.1.0", "255.255.255.0");
  for (int i=0;i<10;i++){
      ipC1T1.push_back (address.Assign (C1T1[i]));
      address.NewNetwork ();
      int nodeid = C1.Get(i)->GetId();
      Ipv4Address addr = ipC1T1[i].GetAddress(1);
      ip_table.insert(std::pair<int,Ipv4Address>(nodeid,addr));
  }

  address.SetBase ("10.2.1.0", "255.255.255.0");
  for (int i=0;i<10;i++){
      ipS1T2.push_back (address.Assign (S1T2[i]));
      address.NewNetwork ();
      int nodeid = S1.Get(i)->GetId();
      Ipv4Address addr = ipS1T2[i].GetAddress(1);
      ip_table.insert(std::pair<int,Ipv4Address>(nodeid,addr));
  }
  address.SetBase ("10.3.1.0", "255.255.255.0");
  for (int i=0;i<10;i++){
      ipS2T3.push_back (address.Assign (S2T3[i]));
      address.NewNetwork ();
      int nodeid = S2.Get(i)->GetId();
      Ipv4Address addr = ipS2T3[i].GetAddress(1);
      ip_table.insert(std::pair<int,Ipv4Address>(nodeid,addr));
  }

  Ipv4GlobalRoutingHelper::PopulateRoutingTables ();

  TypeId tid = TypeId::LookupByName ("ns3::UdpSocketFactory");

  Ptr<Socket> swSink = Socket::CreateSocket(T1,tid);
  InetSocketAddress swlocal = InetSocketAddress(ipT1T2.GetAddress(0),4477);
  swSink->Bind(swlocal);
  swSink->SetRecvCallback(MakeCallback(&SwitchReceivePacket));
  ip_table.insert(std::pair<int,Ipv4Address>(T1->GetId(),ipT1T2.GetAddress(0)));

  swSink = Socket::CreateSocket(T2,tid);
  swlocal = InetSocketAddress(ipT1T2.GetAddress(1),4477);
  swSink->Bind(swlocal);
  swSink->SetRecvCallback(MakeCallback(&SwitchReceivePacket));
  ip_table.insert(std::pair<int,Ipv4Address>(T2->GetId(),ipT1T2.GetAddress(1))); 
  
  
  swSink = Socket::CreateSocket(T3,tid);
  swlocal = InetSocketAddress(ipT1T3.GetAddress(1),4477);
  swSink->Bind(swlocal);
  swSink->SetRecvCallback(MakeCallback(&SwitchReceivePacket));
  ip_table.insert(std::pair<int,Ipv4Address>(T3->GetId(),ipT1T3.GetAddress(1)));


  for (int i=0;i<10;i++){
    Ptr<Socket> recvSink = Socket::CreateSocket (S1.Get (i), tid);
    InetSocketAddress local = InetSocketAddress (ipS1T2[i].GetAddress(1) , 4477);
    recvSink->Bind (local);
    recvSink->SetRecvCallback (MakeCallback (&ServerReceivePacket));
  }

  for (int i=0;i<10;i++){
    Ptr<Socket> recvSink = Socket::CreateSocket (S2.Get (i), tid);
    InetSocketAddress local = InetSocketAddress (ipS2T3[i].GetAddress(1) , 4477);
    recvSink->Bind (local);
    recvSink->SetRecvCallback (MakeCallback (&ServerReceivePacket));
  }

  for (int i=0;i<10;i++){
    Ptr<Socket> recvSink = Socket::CreateSocket (C1.Get (i), tid);
    InetSocketAddress local = InetSocketAddress (ipC1T1[i].GetAddress(1) , 4477);
    recvSink->Bind (local);
    recvSink->SetRecvCallback (MakeCallback (&ClientReceivePacket));
  }
 
  //----------------
  Switch_Init();
  
  //send
  Ptr<Socket> source = Socket::CreateSocket (C1.Get (1), tid);
  InetSocketAddress remote = InetSocketAddress (ipT1T2.GetAddress(0), 4477);
  source->Connect (remote);
  Ptr<Socket> source2 = Socket::CreateSocket(C1.Get(2),tid);
  source2->Connect(remote);

  Ipv4Header ipv4hd;
  ipv4hd.SetSource(ipC1T1[1].GetAddress(1));
  ipv4hd.SetDestination(ipT1T2.GetAddress(0));
  
  //Simulator
  MyHeader hdrkv;
  hdr_kv kv;

  kv.op=OP_READ;
  kv.key = 1;
  kv.value = 0;
      
  hdrkv.SetData(kv);
  Ptr<Packet> pkt = set_packet(ipv4hd,hdrkv);
  //Simulator::Schedule(Seconds(1.0),&SendPacketEvent,source,pkt);

  //LogComponentEnable("DefaultSimulatorImpl",LOG_LOGIC);
  Simulator::ScheduleWithContext(source->GetNode ()->GetId (), Seconds(0),&TestSendPacket,source,pkt,0,10000,Seconds(0));
  

   AsciiTraceHelper ascii;
   p2pST.EnableAsciiAll(ascii.CreateFileStream("test.tr"));
//   p2pTT.EnableAsciiAll(ascii.CreateFileStream("test.tr"));

  Simulator::Stop(Seconds(60.0));
  Simulator::Run ();
  Simulator::Destroy ();
  return 0;
}
