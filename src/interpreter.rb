# TODO
# - parse module
# - parse section
#  - Function section
#  - Table section
#  - Memory section
#  - Global section
#  - Export section
#  - Start section
# - define runtime environment
#  - store(store data)
#  - runtime(runtime data, like stack, call stack)

require_relative 's_expression_parser'

class Store
  attr_accessor :type_section, :function_section, :code_section, :export_section
end

class Runtime
  attr_accessor :exports, :functions, :stack, :frame
end

class Interpreter
  def initialize
    @store = Store.new
    @runtime = Runtime.new
  end

  def load(s_expression)
    s_expression.each do |expression|
      evl(expression)
    end

    self
  end

  def run(func_name, *args)
    call("$#{func_name}", args)
  end

  def call(func_name, args)
    param, body = @store.function_section[func_name]
    @runtime.frame ||= -1
    @runtime.frame += 1
    @runtime.stack ||= {}
    @runtime.stack[@runtime.frame] ||= {}
    @runtime.stack[@runtime.frame][param] = args[0]
    v = eval_body(body)
    @runtime.frame -= 1
    v
  end

  def eval_body(body)
    body.each_with_index do |inst, i|
      if body.size - 1 == i
        v = eval_if(inst)
        return v
      else
        v = eval_if(inst)
        return v unless v.nil?
      end
    end
  end

  def eval_if(body)
    case body
    in ['if', [*condition], ['then', [*then_body]]]
      if eval_exp(condition)
        v = eval_then_body(then_body).to_i
        # p "return: #{v}"
        v
      else
        nil
      end
    else
      v = eval_exp(body)
      # p "add_stack: #{@runtime.stack}"
      v
    end
  end

  def eval_then_body(body)
    case body
    in ['return', [*exp]]
      val = eval_exp(exp)
      # p "add_stack: #{@runtime.stack}"
      val
    else
      raise "unexpected then_body: #{body}"
    end
  end

  def eval_exp(exp)
    case exp
    in ['i32.const', value]
      value
    in ['i32.eq', [*left], [*right]]
      eval_exp(left).to_i == eval_exp(right).to_i
    in ['i32.add', [*left], [*right]]
      v = eval_exp(left).to_i + eval_exp(right).to_i
      # pp "add: #{v}"
      v
    in ['i32.sub', [*left], [*right]]
      eval_exp(left).to_i - eval_exp(right).to_i
    in ['call', name, [*args]]
      call(name, [eval_exp(args)])
    in ['local.get', name]
      @runtime.stack[@runtime.frame][name]
    else
      raise "unexpected exp: #{exp}"
    end
  end

  def evl(expression)
    case expression
    in ['module', *sections]
      evl_module(sections)
    else
      raise "unexpected expression: #{expression}"
    end
  end

  def evl_module(sections)
    sections.each do |section|
      case section
      # when ['type', *instructions]
        # eval_type_section(instructions)
      in ['func', name, *params_and_body]
        eval_function(name, params_and_body)
      in ['export', *instructions]
      else
        raise "unexpected section: #{section}"
      end
    end
  end

  def eval_function(name, params_and_body)
    case params_and_body
    in [['param', param, _], ['result', _], *body]
      @store.function_section ||= {}
      @store.function_section[name] = [param, body]
    else
      raise "unexpected function: #{params_and_body}"
    end
  end

  def parse_params
  end
end
