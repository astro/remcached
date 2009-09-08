require 'remcached/pack_array'

module Memcached
  class Packet
    def initialize(contents={})
      @contents = contents
      (self.class.fields +
       self.class.extras).each do |name,fmt,default|
        self[name] ||= default if default
      end
    end

    def [](field)
      @contents[field]
    end

    def []=(field, value)
      @contents[field] = value
    end

    # Define fields for subclasses
    def self.field(name, packed, default=nil)
      instance_eval do
        @fields ||= []
        @fields << [name, packed, default]
      end
    end

    def self.fields
      parent_class = ancestors[1]
      parent_fields = parent_class.respond_to?(:fields) ? parent_class.fields : []
      class_fields = instance_eval { @fields || [] }
      parent_fields + class_fields
    end

    def self.extra(name, packed, default=nil)
      instance_eval do
        @extras ||= []
        @extras << [name, packed, default]
      end
    end

    def self.extras
      instance_eval { @extras || [] }
    end

    def self.parse_header(buf)
      pack_fmt = fields.collect { |name,fmt,default| fmt }.join
      values = PackArray.unpack(buf, pack_fmt)

      contents = {}
      fields.each do |name,fmt,default|
        contents[name] = values.shift
      end

      new contents
    end

    # Return remaining bytes
    def parse_body(buf)
      buf, rest = buf[0..(self[:total_body_length] - 1)], buf[self[:total_body_length]..-1]

      if self[:extras_length] > 0
        self[:extras] = parse_extras(buf[0..(self[:extras_length]-1)])
      else
        self[:extras] = parse_extras("")
      end
      if self[:key_length] > 0
        self[:key] = buf[self[:extras_length]..(self[:extras_length]+self[:key_length]-1)]
      else
        self[:key] = ""
      end
      self[:value] = buf[(self[:extras_length]+self[:key_length])..-1]

      rest
    end

    def to_s
      extras_s = extras_to_s
      key_s = self[:key].to_s
      value_s = self[:value].to_s
      self[:extras_length] = extras_s.length
      self[:key_length] = key_s.length
      self[:total_body_length] = extras_s.length + key_s.length + value_s.length
      header_to_s + extras_s + key_s + value_s
    end

    protected

    def parse_extras(buf)
      pack_fmt = self.class.extras.collect { |name,fmt,default| fmt }.join
      values = PackArray.unpack(buf, pack_fmt)
      self.class.extras.each do |name,fmt,default|
        @self[name] = values.shift || default
      end
    end

    def header_to_s
      pack_fmt = ''
      values = []
      self.class.fields.each do |name,fmt,default|
        values << self[name]
        pack_fmt += fmt
      end
      PackArray.pack(values, pack_fmt)
    end

    def extras_to_s
      values = []
      pack_fmt = ''
      self.class.extras.each do |name,fmt,default|
        values << self[name] || default
        pack_fmt += fmt
      end

      PackArray.pack(values, pack_fmt)
    end
  end

  ##
  # Request header:
  #
  #   Byte/     0       |       1       |       2       |       3       |
  #      /              |               |               |               |
  #     |0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|
  #     +---------------+---------------+---------------+---------------+
  #    0| Magic         | Opcode        | Key length                    |
  #     +---------------+---------------+---------------+---------------+
  #    4| Extras length | Data type     | Reserved                      |
  #     +---------------+---------------+---------------+---------------+
  #    8| Total body length                                             |
  #     +---------------+---------------+---------------+---------------+
  #   12| Opaque                                                        |
  #     +---------------+---------------+---------------+---------------+
  #   16| CAS                                                           |
  #     |                                                               |
  #     +---------------+---------------+---------------+---------------+
  #     Total 24 bytes
  class Request < Packet
    field :magic, 'C', 0x80
    field :opcode, 'C', 0
    field :key_length, 'n'
    field :extras_length, 'C'
    field :data_type, 'C', 0
    field :reserved, 'n', 0
    field :total_body_length, 'N'
    field :opaque, 'N', 0
    field :cas, 'Q', 0

    def self.parse_header(buf)
      me = super
      me[:magic] == 0x80 ? me : nil
    end

    class Get < Request
      def initialize(contents)
        super(contents.merge :opcode=>Commands::GET)
      end
    end

    class Add < Request
      extra :flags, 'N', 0
      extra :expiration, 'N', 0

      def initialize(contents)
        super(contents.merge :opcode=>Commands::ADD)
      end
    end

    class Set < Request
      extra :flags, 'N', 0
      extra :expiration, 'N', 0

      def initialize(contents)
        super(contents.merge :opcode=>Commands::SET)
      end
    end

    class Delete < Request
      def initialize(contents)
        super(contents.merge :opcode=>Commands::DELETE)
      end
    end

    class Stats < Request
      def initialize(contents)
        super(contents.merge :opcode=>Commands::STAT)
      end
    end
  end

  ##
  # Response header:
  #
  #   Byte/     0       |       1       |       2       |       3       |
  #      /              |               |               |               |
  #     |0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|
  #     +---------------+---------------+---------------+---------------+
  #    0| Magic         | Opcode        | Key Length                    |
  #     +---------------+---------------+---------------+---------------+
  #    4| Extras length | Data type     | Status                        |
  #     +---------------+---------------+---------------+---------------+
  #    8| Total body length                                             |
  #     +---------------+---------------+---------------+---------------+
  #   12| Opaque                                                        |
  #     +---------------+---------------+---------------+---------------+
  #   16| CAS                                                           |
  #     |                                                               |
  #     +---------------+---------------+---------------+---------------+
  #     Total 24 bytes
  class Response < Packet
    field :magic, 'C', 0x81
    field :opcode, 'C', 0
    field :key_length, 'n'
    field :extras_length, 'C'
    field :data_type, 'C', 0
    field :status, 'n', Errors::NO_ERROR
    field :total_body_length, 'N'
    field :opaque, 'N', 0
    field :cas, 'Q', 0

    def self.parse_header(buf)
      me = super
      me[:magic] == 0x81 ? me : nil
    end
  end
end
