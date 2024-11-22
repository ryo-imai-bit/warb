p File.binread('./fib.wasm').each_byte.map { |b| b.to_s(16).rjust(2, '0') }
