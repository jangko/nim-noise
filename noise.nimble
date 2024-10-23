# packageName   = "noise"
version       = "0.1.10"
author        = "Andri Lim"
description   = "noise is a Nim implementation of linenoise"
license       = "MIT"
skipDirs      = @["examples"]

requires: "nim >= 0.18.1"

### Helper functions
proc test(env, path: string) =
  # Compilation language is controlled by TEST_LANG
  var lang = "c"
  if existsEnv"TEST_LANG":
    lang = getEnv"TEST_LANG"

  if not dirExists "build":
    mkDir "build"
  exec "nim " & lang & " " & env &
    " --hints:off --warnings:off " & path

task test, "Run all tests":
  test "-d:prompt_no_history", "examples/test"
  test "-d:prompt_no_kill", "examples/test"
  test "-d:prompt_no_completion", "examples/test"
  test "-d:prompt_no_word_editing", "examples/test"
  test "-d:prompt_no_preload_buffer", "examples/test"
  test "-d:prompt_no_incremental_history_search", "examples/test"

  test "-d:release -d:prompt_no_history", "examples/test"
  test "-d:release -d:prompt_no_kill", "examples/test"
  test "-d:release -d:prompt_no_completion", "examples/test"
  test "-d:release -d:prompt_no_word_editing", "examples/test"
  test "-d:release -d:prompt_no_preload_buffer", "examples/test"
  test "-d:release -d:prompt_no_incremental_history_search", "examples/test"

  test "-d:release -d:prompt_no_basic", "examples/primitives"
  test "-d:prompt_no_basic", "examples/primitives"
