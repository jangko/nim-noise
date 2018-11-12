packageName   = "noise"
version       = "0.1.3"
author        = "Andri Lim"
description   = "noise is a Nim implementation of linenoise"
license       = "MIT"
skipDirs      = @["examples"]

requires: "nim >= 0.18.1"

task test, "Run all tests":
  exec "nim c -d:prompt_no_history examples/test"
  exec "nim c -d:prompt_no_kill examples/test"
  exec "nim c -d:prompt_no_completion examples/test"
  exec "nim c -d:prompt_no_word_editing examples/test"
  exec "nim c -d:prompt_no_preload_buffer examples/test"
  exec "nim c -d:prompt_no_incremental_history_search examples/test"

  exec "nim c -d:release -d:prompt_no_history examples/test"
  exec "nim c -d:release -d:prompt_no_kill examples/test"
  exec "nim c -d:release -d:prompt_no_completion examples/test"
  exec "nim c -d:release -d:prompt_no_word_editing examples/test"
  exec "nim c -d:release -d:prompt_no_preload_buffer examples/test"
  exec "nim c -d:release -d:prompt_no_incremental_history_search examples/test"

  exec "nim c -d:release -d:prompt_no_basic examples/primitives"
  exec "nim c -d:prompt_no_basic examples/primitives"