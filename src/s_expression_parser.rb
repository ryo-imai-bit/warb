class SExpressionParser
  def parse(input)
    @string = input
    s_expression = parse_expressions(terminated_by: %r{\A\z})
    read %r{\z}
    s_expression
  end

  def parse_expressions(terminated_by:)
    expressions = []
    while (expression = parse_expression(terminated_by: terminated_by))
      expressions << expression
    end
    expressions
  end

  def parse_expression(terminated_by:)
    skip_whitespace_and_comments

    case peek
    when terminated_by
      nil
    when %r{\(}
      parse_list
    when %r{"}
      parse_string
    else
      parse_atom
    end
  end

  BLOCK_COMMENT_REGEXP =
  %r{
    (?<comment>
      \(;
        (
          (
            [^(;]
            |
            ; (?!\))
            |
            \( (?!;)
          )
          |
          \g<comment>
        )*
      ;\)
    )
  }x

  def can_read?(pattern)
    !try_match(pattern).nil?
  end

  def skip_whitespace_and_comments
    loop do
      if can_read? %r{[ \t\n\r]+}
        read %r{[ \t\n\r]+}
      elsif can_read? %r{;;.*$}
        # 行末またはファイル末尾までコメントを読み飛ばす
        read %r{;;.*$}
      elsif can_read? BLOCK_COMMENT_REGEXP
        read BLOCK_COMMENT_REGEXP
      else
        break
      end
    end
  end

  def peek
    @string.match(%r{\A.}).to_s
  end

  def parse_atom
    # characters that does not contain a space, quotation mark, comma, semicolon, or bracket. ref: https://webassembly.github.io/spec/core/text/values.html#text-idchar
    read %r{[^() \n;]+}
  end

  def parse_list
    read %r{\(}
    expressions = parse_expressions(terminated_by: %r{\)})
    read %r{\)}
    expressions
  end

  def parse_string
    read %r{"}
    # "ではない文字とエスケープされた"を読む
    string = read %r{(?:\\"|[^"])*}
    read %r{"}
    "\"#{string}\""
  end

  def try_match(regexp)
    %r{\A#{regexp}}.match(@string)
  end

  def read(regexp)
    match = try_match(regexp) || complain(regexp)
    @string = match.post_match
    match.to_s
  end

  def complain(pattern)
    raise "couldn’t find #{pattern} in #{@string.inspect}"
  end
end
