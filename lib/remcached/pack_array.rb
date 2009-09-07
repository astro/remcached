##
# Works exactly like Array#pack and String#unpack, except that it
# inverts 'q' & 'Q' prior packing/after unpacking. This is done to
# achieve network byte order for these values on a little-endian machine.
#
# FIXME: implement check for big-endian machines.
module Memcached::PackArray
  def self.pack(ary, fmt1)
    fmt2 = ''
    values = []
    fmt1.each_char do |c|
      if c == 'Q' || c == 'q'
        fmt2 += 'a8'
        values << [ary.shift].pack(c).reverse
      else
        fmt2 += c
        values << ary.shift
      end
    end

    values.pack(fmt2)
  end

  def self.unpack(buf, fmt1)
    fmt2 = ''
    reverse = []
    i = 0
    fmt1.each_char do |c|
      if c == 'Q' || c == 'q'
        fmt2 += 'a8'
        reverse << [i, c]
      else
        fmt2 += c
      end
      i += 1
    end

    ary = buf.unpack(fmt2)

    reverse.each do |i, c|
      ary[i], = ary[i].reverse.unpack(c)
    end

    ary
  end
end
