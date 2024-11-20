require_relative 'interpreter'

s_expression = SExpressionParser.new.parse(File.read('./fib.wast'))
itp = Interpreter.new.load(s_expression)
p itp.run(ARGV[0], ARGV[1])
