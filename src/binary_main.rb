require_relative 'interpreter'

s_expression = SExpressionParser.new.parse(File.binread('./fib.wasm').each_byte.map { |b| b.to_s(16).rjust(2, '0') })
p s_expression
itp = Interpreter.new.load(s_expression)
p itp.run(ARGV[0], ARGV[1])
