require_relative 's_expression_parser'

s_expression = SExpressionParser.new.parse(ARGF.read)
pp s_expression
