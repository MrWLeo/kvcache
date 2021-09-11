#ifndef MYHEADER_H
#define MYHEADER_H

#include "ns3/ptr.h"
#include "ns3/packet.h"
#include "ns3/header.h"

namespace ns3{

struct hdr_kv{
  uint16_t op;  //!< Header data
  uint32_t key;
  uint32_t value;
  uint32_t version;
  uint16_t server_id;    
  uint16_t chain_id;    
  uint16_t chain_offset;    
  uint16_t chain_length;
  uint16_t status;
};

#define OP_READ  0x1
#define OP_WRITE 0x2
#define OP_WRITE_REPLY 0x3
#define OP_READ_REPLY 0x4
#define OP_WRITE_UNCACHE 0x5

#define ON_QUERY 0x0
#define ON_ROUTING 0x1

class MyHeader : public Header 
{
public:

  MyHeader ();
  virtual ~MyHeader ();

  void SetData (hdr_kv data);
  void SetData2 (uint16_t a,uint32_t b,uint32_t c,uint16_t d);
  hdr_kv GetData (void) const;

  static TypeId GetTypeId (void);
  virtual TypeId GetInstanceTypeId (void) const;
  virtual void Print (std::ostream &os) const;
  virtual void Serialize (Buffer::Iterator start) const;
  virtual uint32_t Deserialize (Buffer::Iterator start);
  virtual uint32_t GetSerializedSize (void) const;
private:
  uint16_t m_op;  //!< Header data
  uint32_t m_key;
  uint32_t m_value;
  uint32_t m_version;
  uint16_t m_server_id;
  uint16_t m_chain_id;    
  uint16_t m_chain_offset;    
  uint16_t m_chain_length;
  uint16_t m_status;
};

MyHeader::MyHeader ()
{
  // we must provide a public default constructor, 
  // implicit or explicit, but never private.
  m_op = 0;
  m_key=0;
  m_value = 0;
  m_version = 0;
  m_server_id = 0;
  m_chain_id = 0;
  m_chain_offset = 0;
  m_chain_length = 0;
  m_status = 0;
}
MyHeader::~MyHeader ()
{
}

TypeId
MyHeader::GetTypeId (void)
{
  static TypeId tid = TypeId ("ns3::MyHeader")
    .SetParent<Header> ()
    .AddConstructor<MyHeader> ()
  ;
  return tid;
}
TypeId
MyHeader::GetInstanceTypeId (void) const
{
  return GetTypeId ();
}

void
MyHeader::Print (std::ostream &os) const
{
  // This method is invoked by the packet printing
  // routines to print the content of my header.
  //os << "data=" << m_data << std::endl;
  os << m_op<<","<<m_key<<","<<m_value<<","
     << m_version<<","<<m_server_id<<","<<m_chain_id<<","<<m_chain_offset<<","<<m_chain_length<<","<<m_status;
}
uint32_t
MyHeader::GetSerializedSize (void) const
{
  // we reserve 2 bytes for our header.
  return 24;
}
void
MyHeader::Serialize (Buffer::Iterator start) const
{
  // we can serialize two bytes at the start of the buffer.
  // we write them in network byte order.

  start.WriteHtonU16 (m_op);
  start.WriteHtonU32 (m_key);
  start.WriteHtonU32 (m_value);
  start.WriteHtonU32 (m_version);
  start.WriteHtonU16 (m_server_id);
  start.WriteHtonU16 (m_chain_id);
  start.WriteHtonU16 (m_chain_offset);
  start.WriteHtonU16 (m_chain_length);
  start.WriteHtonU16 (m_status);
}
uint32_t
MyHeader::Deserialize (Buffer::Iterator start)
{
  // we can deserialize two bytes from the start of the buffer.
  // we read them in network byte order and store them
  // in host byte order.
  m_op = start.ReadNtohU16();
  m_key = start.ReadNtohU32 ();
  m_value = start.ReadNtohU32 ();
  m_version = start.ReadNtohU32 ();
  m_server_id = start.ReadNtohU16 ();
  m_chain_id = start.ReadNtohU16 ();
  m_chain_offset = start.ReadNtohU16 ();
  m_chain_length = start.ReadNtohU16 ();
  m_status = start.ReadNtohU16();

  // we return the number of bytes effectively read.
  return 24;
}

void 
MyHeader::SetData (hdr_kv data)
{
  m_op = data.op;
  m_key = data.key;
  m_value = data.value;
  m_version = data.version;
  m_server_id = data.server_id;
  m_chain_id = data.chain_id;
  m_chain_offset = data.chain_offset;
  m_chain_length = data.chain_length;
  m_status = data.status;
}

void
MyHeader::SetData2 (uint16_t a,uint32_t b,uint32_t c,uint16_t d){
  
  m_op = a;
  m_key = b;
  m_version = c;
  m_server_id = d;

}

hdr_kv
MyHeader::GetData (void) const
{
  hdr_kv data;
  data.op = m_op;
  data.key = m_key;
  data.value = m_value;
  data.version = m_version;
  data.server_id = m_server_id;
  data.chain_id = m_chain_id;
  data.chain_offset = m_chain_offset;
  data.chain_length = m_chain_length;
  data.status = m_status;
  return data;
}


}
#endif