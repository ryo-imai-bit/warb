require_relative 'frame'

class Instructions
  class << self
    def execute(mod, stack, opcode)
      # p mod, stack, opcode
      case opcode
      when 0x02, 0x03
        op_block(mod, stack)
      when 0x04
        op_if(mod, stack)
      when 0x0B
        op_end(mod, stack)
      when 0x0C
        op_br(mod, stack)
      when 0x0D
        op_br_if(mod, stack)
      when 0x20
        op_local_get(mod, stack)
      when 0x21
        op_local_set(mod, stack)
      when 0x22
        op_local_tee(mod, stack)
      when 0x41
        op_i32_const(mod, stack)
      when 0x46
        op_i32_eq(mod, stack)
      when 0x6A
        op_i32_add(mod, stack)
      when 0x6B
        op_i32_sub(mod, stack)
      when 0x10
        op_call(mod, stack)
      else
        raise "Unsupported opcode: #{opcode.to_s(16)}"
      end
    end

    def call(mod, stack, func_index)
      p "call func_index: #{func_index}"
      raise "Invalid function index" if func_index >= mod.function_sections.size

      args = []
      func = mod.function_sections[func_index]
      func.type.params.reverse.each do |val_type|
        args.unshift(stack.pop_value(val_type))
      end

      stack.push_frame(Frame.new(func, args))
    end

    private

      def op_block(mod, stack)
        block_start_pc = stack.current_instr.pos + 1

        label = stack.current_frame.function.blocks[block_start_pc]
        stack.current_instr.pos = label.start_pc

        stack.push_label(label)
      end

      def op_if(mod, stack)
        # 次の数字をliteralとして想定し、記述する
        # popした値が1の場合はframeを抜け、0の場合はblockを実行する
        _if_type = stack.current_instr.next_byte
        # _lite_type = stack.current_instr.next_byte
        # literal = stack.current_instr.read_signed_leb128

        if stack.pop_value('i32').value == 1
          _lite_type = stack.current_instr.next_byte
          literal = stack.current_instr.read_signed_leb128

          p 'if true', literal
          return_value = Value.new('i32', literal)
          stack.push_values([return_value])
          stack.pop_current_frame
          p stack
        else
          p 'if false'
          # endまで飛ばし、blockを実行する
          while stack.current_instr.next_byte != 0x0B
            p 'if skip', stack
          end
          p 'if end', stack, stack.current_instr.pc
        end
      end

      def op_end(mod, stack)
        if !stack.current_instr.eof?
          stack.pop_last_label
          return
        end

        result_type = stack.current_frame.function.func_type.results.first
        result = stack.pop_value(result_type)

        if !stack.peek.equal?(stack.current_frame)
          raise "Stack top is NOT current frame"
        end

        stack.pop_current_frame
        stack.push_values([result])
      end

      def op_br(mod, stack)
        label_idx = stack.current_instr.next_byte
        raise "Invalid label index" if stack.current_labels < label_idx + 1

        label = stack.label(label_idx)
        value = label.arity.any? ? stack.pop_value(label.arity.first) : nil

        stack.pop_all_from_label(label_idx)
        stack.push(value) if value

        stack.current_instr.pos =
          if label.instr == 0x03 # loop
            label.start_pc - 2
          else
            label.end_pc + 1
          end
      end

      def op_br_if(mod, stack)
        if stack.pop_value('i32').value == 0
          stack.current_instr.next_byte
        else
          op_br(mod, stack)
        end
      end

      def op_local_get(mod, stack)
        local_idx = stack.current_instr.next_byte
        local_value = [stack.current_frame.reference_local_var(local_idx).dup]
        p 'local_get', local_idx, local_value
        stack.push_values(local_value)
      end

      def op_local_set(mod, stack)
        local_idx = stack.current_instr.next_byte
        local_var = stack.current_frame.reference_local_var(local_idx)

        local_var.assign(stack.pop_value(local_var.type))
      end

      def op_local_tee(mod, stack)
        local_idx = stack.current_instr.next_byte
        stack.current_frame.reference_local_var(local_idx).assign(stack.peek)
      end

      def op_i32_const(mod, stack)
        value = stack.current_instr.next_byte
        stack.push_values([Value.new('i32', value)])
      end

      def op_i32_eq(mod, stack)
        p 'eq before', stack
        c2 = stack.pop_value('i32')
        c1 = stack.pop_value('i32')
        p 'eq', c1, c2

        stack.push_values([Value.new('i32', c1.value == c2.value ? 1 : 0)])
      end

      def op_i32_add(mod, stack)
        c2 = stack.pop_value('i32')
        c1 = stack.pop_value('i32')

        stack.push_values([Value.new('i32', c1.value + c2.value)])
      end

      def op_i32_sub(mod, stack)
        c2 = stack.pop_value('i32')
        c1 = stack.pop_value('i32')
        p 'sub', c1, c2

        stack.push_values([Value.new('i32', c1.value - c2.value)])
      end

      def op_call(mod, stack)
        func_index = stack.current_instr.next_byte
        p 'func_index', func_index
        call(mod, stack, func_index)
      end
  end
end
