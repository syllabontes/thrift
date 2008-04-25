/**
 * Autogenerated by Thrift
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 */

#include "shared_types.h"

gint32 thrift_shared_struct_write (ThriftStruct * object, ThriftProtocol * thrift_protocol)
{
  gint32 xfer = 0;
  ThriftSharedStruct * this_object = THRIFT_SHARED_STRUCT(object);
  xfer += thrift_protocol_write_struct_begin (thrift_protocol, "SharedStruct");
  xfer += thrift_protocol_write_field_begin (thrift_protocol, "key", T_I32, 1);
  xfer += thrift_protocol_write_i32(thrift_protocol, this_object->key);
  xfer += thrift_protocol_write_field_end (thrift_protocol);
  xfer += thrift_protocol_write_field_begin (thrift_protocol, "value", T_STRING, 2);
  xfer += thrift_protocol_write_string(thrift_protocol, this_object->value);
  xfer += thrift_protocol_write_field_end (thrift_protocol);
  xfer += thrift_protocol_write_field_stop(thrift_protocol);
  xfer += thrift_protocol_write_struct_end(thrift_protocol);
  return xfer;
}

void thrift_shared_struct_instance_init (ThriftSharedStruct * object)
{
  object->key = 0;
  object->value = "";
}

void thrift_shared_struct_class_init (ThriftStructClass * thrift_struct_class)
{
  thrift_struct_class->write = thrift_shared_struct_write;
}

GType thrift_shared_struct_get_type (void)
{
  static GType type = 0;

  if (type == 0) 
  {
    static const GTypeInfo type_info = 
    {
      sizeof (ThriftSharedStructClass),
      NULL, /* base_init */
      NULL, /* base_finalize */
      (GClassInitFunc)thrift_shared_struct_class_init,
      NULL, /* class_finalize */
      NULL, /* class_data */
      sizeof (ThriftSharedStruct),
      0, /* n_preallocs */
      (GInstanceInitFunc)thrift_shared_struct_instance_init,
      NULL, /* value_table */
    };

    type = g_type_register_static (THRIFT_TYPE_STRUCT, 
                                   "ThriftSharedStructType",
                                   &type_info, 0);
  }

  return type;
}
