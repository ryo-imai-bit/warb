# とりあえずバイナリフォーマットからのパースをテストする
# assert_parse '(module (func $fib (param $N i32) (result i32) (if (i32.eq (local.get $N) (i32.const 0)) (then (return (i32.const 0))) ) (if (i32.eq (local.get $N) (i32.const 1)) (then (return (i32.const 1))) ) (i32.add (call $fib (i32.sub (local.get $N) (i32.const 1))) (call $fib (i32.sub (local.get $N) (i32.const 2))) ) ) (export "fib" (func $fib)) )', ["00", "61", "73", "6d", "01", "00", "00", "00", "01", "06", "01", "60", "01", "7f", "01", "7f", "03", "02", "01", "00", "07", "07", "01", "03", "66", "69", "62", "00", "00", "0a", "29", "01", "27", "00", "20", "00", "41", "00", "46", "04", "40", "41", "00", "0f", "0b", "20", "00", "41", "01", "46", "04", "40", "41", "01", "0f", "0b", "20", "00", "41", "01", "6b", "10", "00", "20", "00", "41", "02", "6b", "10", "00", "6a", "0b"]
assert_parse '(module (func $fib (param $N i32) (result i32) (if (i32.eq (local.get $N) (i32.const 0)) (then (return (i32.const 0))) ) (if (i32.eq (local.get $N) (i32.const 1)) (then (return (i32.const 1))) ) (i32.add (call $fib (i32.sub (local.get $N) (i32.const 1))) (call $fib (i32.sub (local.get $N) (i32.const 2))) ) ) (export "fib" (func $fib)) )', [1, 6, 1, 96, 1, 127, 1, 127, 3, 2, 1, 0, 7, 7, 1, 3, 102, 105, 98, 0, 0, 10, 41, 1, 39, 0, 32, 0, 65, 0, 70, 4, 64, 65, 0, 15, 11, 32, 0, 65, 1, 70, 4, 64, 65, 1, 15, 11, 32, 0, 65, 1, 107, 16, 0, 32, 0, 65, 2, 107, 16, 0, 106, 11]
# 最終的に目指すアウトプット
# assert_parse '(module (func $fib (param $N i32) (result i32) (if (i32.eq (local.get $N) (i32.const 0)) (then (return (i32.const 0))) ) (if (i32.eq (local.get $N) (i32.const 1)) (then (return (i32.const 1))) ) (i32.add (call $fib (i32.sub (local.get $N) (i32.const 1))) (call $fib (i32.sub (local.get $N) (i32.const 2))) ) ) (export "fib" (func $fib)) )', [["module", ["func", "$fib", ["param", "$N", "i32"], ["result", "i32"], ["if", ["i32.eq", ["local.get", "$N"], ["i32.const", "0"]], ["then", ["return", ["i32.const", "0"]]]], ["if", ["i32.eq", ["local.get", "$N"], ["i32.const", "1"]], ["then", ["return", ["i32.const", "1"]]]], ["i32.add", ["call", "$fib", ["i32.sub", ["local.get", "$N"], ["i32.const", "1"]]], ["call", "$fib", ["i32.sub", ["local.get", "$N"], ["i32.const", "2"]]]]], ["export", "\"fib\"", ["func", "$fib"]]]]

# assert_parse '(module)', [['hello']]
# assert_parse '(hello world)', [['hello', 'world']]
# assert_parse '((hello goodbye) world)', [[['hello', 'goodbye'], 'world']]
# assert_parse "(module\n  (func (nop))\n)", [['module', ['func', ['nop']]]]
# assert_parse "(module\n  (func(nop))\n)", [['module', ['func', ['nop']]]]
# assert_parse "(module\n  (func (nop)nop)\n)", [['module', ['func', ['nop'], 'nop']]]
# assert_parse '(module) (module)', [['m'], ['module']]
# assert_parse ";; Tokens can be delimited by parentheses\n\n(module\n  (func(nop))\n)", [['module', ['func', ['nop']]]]
# assert_parse "(module\n  (func;;bla\n  )\n)", [['module', ['func']]]
# assert_parse '"(hello world) ;; comment"', ['"(hello world) ;; comment"']
# assert_parse '"hello \" world"', ['"hello \" world"']
# assert_parse '(hello (; cruel ;) world)', [['hello', 'world']]
# assert_parse '(hello (; this; is; ( totally; ); fine ;) world)', [['hello', 'world']]
# assert_parse '(hello (; cruel (; very cruel ;) extremely cruel ;) world)', [['hello', 'world']]
# assert_parse '(hello (; cruel ;) happy (; terrible ;) world)', [['hello', 'happy', 'world']]

BEGIN {
  TEST_WAT = './test/dump/test.wat'
  TEST_WASM = './test/dump/test.wasm'
  require_relative '../src/wasm_parser'

  def dump_to_wasm(wat_expression)
    File.open(TEST_WAT, 'w') { |f| f.write(wat_expression) }
    system("wat2wasm #{TEST_WAT} -o #{TEST_WASM}")
    return File.binread(TEST_WASM).each_byte.map { |b| b }
  end

  def assert_parse(input, expected)
    actual = WasmParser.new.parse(dump_to_wasm(input))
    actual = actual.call('fib', [Value.new('i32', 1)])
    if actual == expected
      print "\e[32m.\e[0m"
    else
      raise "expected #{expected}, got #{actual}"
    end
  end
}

END {
  puts
}
