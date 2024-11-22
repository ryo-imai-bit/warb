
require_relative 'stack'
require_relative 'instructions'

class WasmModule
  attr_accessor :type_sections, :function_sections, :export_sections

  def initialize
    @type_sections = []
    @function_sections = []
    @code_sections = []
    @export_sections = []
  end
end

class Type
  attr_accessor :params, :results

  HEADER = 0x60

  def initialize
    @params = []
    @results = []
  end
end

class ValueType
  I32 = 0x7F
  I64 = 0x7E
  # F32 = 0x7D
  # F64 = 0x7C

  def self.to_s(value_type)
    case value_type
    when I32
      "i32"
    when I64
      "i64"
    # when F32
      # "f32"
    # when F64
      # "f64"
    else
      raise "Invalid value type: #{value_type}"
    end
  end
end

class Value
  attr_reader :type, :value

  def initialize(type, value = nil)
    @type = type
    @value = uninterpret(value || default_value)
  end

  def assign(other_value)
    raise "Invalid value" if !other_value.is_a?(Value) ||
                             type != other_value.type

    @value = other_value.value
  end

  def default_value
    0
  end

  def uninterpret(value)
    value & (2**32 - 1)
  end

  # # # def ==(int)
  # #   self.class == int.class && bits == int.bits
  # end
end

class Function
  STRUCTURED_INSTRS = [0x04, 0x0B]
  OP_END = 0x0B

  Block = Struct.new(:instr, :param, :start_pc, :end_pc)

  attr_accessor :type, :locals, :instruction, :blocks, :pc

  def initialize(type:)
    @type = type
    @locals = []
    @instruction = []
    @blocks = {}
    @pc = 0
  end

  def next_byte
    i = @instruction[@pc]
    @pc += 1
    p "i: #{i.to_s(16)}, pc: #{@pc}"
    i
  end


  def read_signed_leb128
    value = 0
    shift = 0

    loop do
      b = next_byte
      p 'read_signed_leb128', b, b.to_s(16)
      value |= ((b & 0x7F) << shift)

      shift += 7
      p 'read_signed_leb128', value, shift
      break if b[7] == 0

      raise "Invalid Signed LEB128 encoding" if shift >= max_bits
    end

    value |= (~0 << shift) if value[shift - 1] == 1
    value
  end

  def create_local_variables
    @locals.map {|val_type| Value.new(val_type) }
  end

  def peek_block(insts)
    loop do
      instr = insts.shift(1)[0]
      if STRUCTURED_INSTRS.include?(instr)
        break instr
      else
        # 構造化命令以外はスキップ
        case instr
        when 0x0F # return
          insts.shift(1)
        when 0x10 # call
          insts.shift(1)
        when 0x0C, 0x0D # br, br_if
          insts.shift(1)
        when (0x20...0x24) # local.get ~ global.set
          insts.shift(1)
        when 0x41, 0x42 # i32.const, i64.const
          insts.shift(1)
        when (0x45...0xBF) # i32.eqz ~ f64.reinterpret_i64
          nil
        else
          raise "Unsupported instruction: #{instr}"
        end
      end
    end
  end

  # function毎に1回
  def peek_blocks
    block_stack = [Block.new(0x02, @type.results, 0, nil)]
    insts = @instruction.dup

    # @instructions.each_with_index do |instr, i|
    #   case instr
    #   when 0x02
    #     @blocks.last.end_pc = i
    #     @blocks << Block.new(instr, @type.results, i + 1, nil)
    #   end
    # end

    while block_stack.any? do
      instr = peek_block(insts)

      if instr == OP_END
        p 'end', block_stack
        block = block_stack.pop
        block.end_pc = insts.size - 1

        @blocks[block.start_pc] = block
      else
        block_type = insts.shift(1)[0]
        arity = (block_type == 0x40 ? [] : [ValueType.decode(block_type)])

        block_stack << Block.new(instr, arity, @instruction.size - insts.size, nil)
      end
    end
  end
end

class Export
  FUNC = 0x00
  TABLE = 0x01
  MEMORY = 0x02
  GLOBAL = 0x03

  attr_accessor :name, :desc, :function

  def initialize(name:, desc:, function:)
    @name = name
    @desc = case desc
            when FUNC
              "func"
            when TABLE
              "table"
            when MEMORY
              "memory"
            when GLOBAL
              "global"
            else
              raise "Invalid export description: #{desc}"
            end
    @function = function
  end
end

class WasmParser
  # Custom = 00
  TYPE = 1
  # Import = 02
  FUNCTION = 3
  # TABLE = 4
  # MEMORY = 5
  # GLOBAL = 6
  EXPORT = 7
  # START = 8
  # ELEMENT = 9
  CODE = 10
  # DATA = 11

  # input: array[hex]
  def parse(input)
    @bytes = input
    @module = WasmModule.new
    parse_module

    self
  end

  def parse_module
    # 先頭8バイトはマジックナンバーとバージョン情報なので読み飛ばす
    @bytes.shift(8)

    parse_sections
  end

  def parse_sections
    loop do
      break if @bytes.empty?

      # 先頭1バイトがsection_id, その後ろがsection_size
      section_id = @bytes.shift(1)[0]

      case section_id
      when TYPE
        parse_type_section
      when FUNCTION
        parse_function_section
      when EXPORT
        parse_export_section
      when CODE
        parse_code_section
      else
        # 未実装はとりあえず読み飛ばす
        break
      end
    end
  end

  def parse_type_section
    _section_size = read_unsigned_leb128
    section_count = read_unsigned_leb128

    section_count.times do
      @module.type_sections << parse_type
    end
  end

  def parse_type
    header = @bytes.shift(1)[0]
    raise "Invalid type header" if header != Type::HEADER

    t = Type.new

    # 関数の引数の数
    param_count = read_unsigned_leb128
    t.params = @bytes.shift(param_count).map { |value_type| ValueType.to_s(value_type) }
    # 関数の戻り値の数
    result_count = read_unsigned_leb128
    t.results = @bytes.shift(result_count).map { |value_type| ValueType.to_s(value_type) }

    t
  end

  def parse_function_section
    _section_size = read_unsigned_leb128
    function_count = read_unsigned_leb128

    function_count.times do
      index = read_unsigned_leb128
      @module.function_sections << Function.new(type: @module.type_sections[index])
    end
  end

  def parse_export_section
    _section_size = read_unsigned_leb128
    export_count = read_unsigned_leb128

    export_count.times do
      name_len = read_unsigned_leb128
      name = @bytes.shift(name_len).pack("C*")

      desc = @bytes.shift(1)[0]
      index = read_unsigned_leb128

      @module.export_sections << Export.new(name: name, desc: desc, function: @module.function_sections[index])
    end
  end

  def parse_code_section
    _section_size = read_unsigned_leb128
    code_count = read_unsigned_leb128

    code_count.times do |i|
      func = @module.function_sections[i]

      code_size = read_unsigned_leb128
      first_position = @bytes.size

      # 0になるがlocalに定義していないので大丈夫
      local_count = read_unsigned_leb128

      local_count.times do
        count = read_unsigned_leb128
        type = ValueType.to_s(@bytes.shift(1)[0])

        func.locals += [type] * count
      end

      end_position = @bytes.size

      func.instruction = @bytes.shift(code_size - (end_position - first_position))
      # func.peek_blocks
    end
  end

  def read_unsigned_leb128
    value = 0
    shift = 0

    loop do
      b = @bytes.shift
      value |= ((b & 0x7F) << shift)

      shift += 7
      break if b[7] == 0

      raise "Invalid LEB128 encoding" if shift >= 32
    end

    value
  end

  def read_signed_leb128(max_bits)
    value = 0
    shift = 0

    loop do
      b = @bytes.shift
      value |= ((b & 0x7F) << shift)

      shift += 7
      break if b[7] == 0

      raise "Invalid Signed LEB128 encoding" if shift >= max_bits
    end

    value |= (~0 << shift) if value[shift - 1] == 1
    value
  end

  # func_namesをexportsから取得しargsをcallに渡し、スタックマシン上で実行する
  def call(func_name, args)
    stack = Stack.new
    stack.push_values(args)

    func_idx = @module.function_sections.index { |func| func == @module.export_sections.find { |export| export.name == func_name }.function }
    Instructions.call(@module, stack, func_idx)

    begin
      while stack.current_frame do
        # next_byteを呼び出すとpcが進む、10進数で返す
        Instructions.execute(@module, stack, stack.current_instr.next_byte)
      end

      stack.stack.to_a
    rescue => e
      stack_content = stack.to_a
      raise "Interpretation error! [#{e.class}:#{e.message}] stack:#{stack_content.size}/#{stack_content}"
    end
  end
end
