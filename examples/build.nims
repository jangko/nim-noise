exec "nim c --path:.. -d:prompt_no_history test"
exec "nim c --path:.. -d:prompt_no_kill test"
exec "nim c --path:.. -d:prompt_no_completion test"
exec "nim c --path:.. -d:prompt_no_word_editing test"
exec "nim c --path:.. -d:prompt_no_preload_buffer test"
exec "nim c --path:.. -d:prompt_no_incremental_history_search test"

exec "nim c --path:.. -d:release -d:prompt_no_history test"
exec "nim c --path:.. -d:release -d:prompt_no_kill test"
exec "nim c --path:.. -d:release -d:prompt_no_completion test"
exec "nim c --path:.. -d:release -d:prompt_no_word_editing test"
exec "nim c --path:.. -d:release -d:prompt_no_preload_buffer test"
exec "nim c --path:.. -d:release -d:prompt_no_incremental_history_search test"

exec "nim c --path:.. -d:release -d:prompt_no_basic primitives"
exec "nim c --path:.. -d:prompt_no_basic primitives"