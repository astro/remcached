module Memcached
  module Datatypes
    RAW_BYTES = 0x00
  end

  module Errors
    NO_ERROR = 0x0000
    KEY_NOT_FOUND = 0x0001
    KEY_EXISTS = 0x0002
    VALUE_TOO_LARGE = 0x0003
    INVALID_ARGS = 0x0004
    ITEM_NOT_STORED = 0x0005
    NON_NUMERIC_VALUE = 0x0006

    DISCONNECTED = 0xffff
  end

  module Commands
    GET = 0x00
    SET = 0x01
    ADD = 0x02
    REPLACE = 0x03
    DELETE = 0x04
    INCREMENT = 0x05
    DECREMENT = 0x06
    QUIT = 0x07

=begin
   Possible values of the one-byte field:
   0x00    Get
   0x01    Set
   0x02    Add
   0x03    Replace
   0x04    Delete
   0x05    Increment
   0x06    Decrement
   0x07    Quit
   0x08    Flush
   0x09    GetQ
   0x0A    No-op
   0x0B    Version
   0x0C    GetK
   0x0D    GetKQ
   0x0E    Append
   0x0F    Prepend
   0x10    Stat
   0x11    SetQ
   0x12    AddQ
   0x13    ReplaceQ
   0x14    DeleteQ
   0x15    IncrementQ
   0x16    DecrementQ
   0x17    QuitQ
   0x18    FlushQ
   0x19    AppendQ
   0x1A    PrependQ
=end
  end
end
