require_relative '../src/interpreter'


def fib(n)
  return  n  if n <= 1
  fib( n - 1 ) + fib( n - 2 )
end

def assert_fib(n)
  s_expression = SExpressionParser.new.parse(File.read('./fib.wast'))
  itp = Interpreter.new.load(s_expression)
  if itp.run("fib", n) != fib(n)
    raise "fib(#{n}) != #{fib(n)}"
  else
    print "\e[32m.\e[0m"
  end
end

assert_fib(1)
assert_fib(2)
assert_fib(3)
assert_fib(4)
assert_fib(5)
assert_fib(6)
assert_fib(7)
