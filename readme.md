# noise
[![Build Status (Travis)](https://img.shields.io/travis/jangko/nim-noise/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/jangko/nim-noise)
[![Windows build status (Appveyor)](https://img.shields.io/appveyor/ci/jangko/nim-noise/master.svg?label=Windows "Windows build status (Appveyor)")](https://ci.appveyor.com/project/jangko/nim-noise)

Nim implementation of linenoise line editor, inspired by
[replxx](https://github.com/AmokHuginnsson/replxx) and
[linenoise-ng](https://github.com/arangodb/linenoise-ng)

## Features
  * Line editing with emacs keybindings
  * History handling
  * Completion
  * Hints(work in progress)
  * Syntax Coloring(work in progress)
  * UTF-8 aware
  * Intuitive ESC key sub menu escaping
  * A bunch of compile time switch to select which features you want to turn on/off
  * Support Windows, Linux and Mac OS

## API

Basic API:
* proc init*(x: typedesc[Noise]): Noise
* proc getKeyType*(self: Noise): KeyType
* proc getLine*(self: var Noise): string
* proc readLine*(self: var Noise): bool
* proc setPrompt*(self: var Noise, text: Styler)

History API:
* proc historyAdd*(self: var Noise, line: string)
* proc historySetMaxLen*(self: var Noise, len: int): bool
* iterator histories*(self: var Noise): string
* iterator historyPairs*(self: var Noise): (int, string)
* proc historySave*(self: var Noise, fileName: string): bool
* proc historyLoad*(self: var Noise, fileName: string): bool
* proc historyClear*(self: var Noise)

Completion API:
* proc setCompletionHook*(self: var Noise, prc: CompletionHook)
* proc addCompletion*(self: var Noise, text: string)

PreloadBuffer API:
* proc preloadBuffer*(self: var Noise, preloadText: string)

## Examples
```Nim
proc main() =
  var noise = Noise.init()

  let prompt = Styler.init(fgRed, "Red ", fgGreen, "苹果> ")
  noise.setPrompt(prompt)

  when promptPreloadBuffer:
    noise.preloadBuffer("Superman")

  when promptHistory:
    var file = "history"
    discard noise.historyLoad(file)

  when promptCompletion:
    proc completionHook(noise: var Noise, text: string): int =
      const words = ["apple", "diamond", "diadem", "diablo", "horse", "home", "quartz", "quit"]
      for w in words:
        if w.find(text) != -1:
          noise.addCompletion w

    noise.setCompletionHook(completionHook)

  while true:
    let ok = noise.readLine()
    if not ok: break

    let line = noise.getLine
    case line
    of ".help": printHelp()
    of ".quit": break
    else: discard

    when promptHistory:
      if line.len > 0:
        noise.historyAdd(line)

  when promptHistory:
    discard noise.historySave(file)

main()
```

## Key Binding
```text
  # Completion
    CTRL-I/TAB                   activates completion
  # History
    CTRL-P, UP_ARROW_KEY         recall previous line in history
    CTRL-N, DOWN_ARROW_KEY       recall next line in history
    CTRL-R                       reverse history search
    CTRL-S                       forward history search
    ALT-<, PAGE_UP_KEY           beginning of history
    ALT->, PAGE_DOWN_KEY         end of history
  # Kill and Yank
    ALT-d, ALT-D:                kill word to right of cursor
    ALT + Backspace:             kill word to left of cursor
    CTRL-K                       kill from cursor to end of line
    CTRL-U                       kill all characters to the left of the cursor
    CTRL-W                       kill to whitespace (not word) to left of cursor
    CTRL-Y                       yank killed text
    ALT-y, ALT-Y                 'yank-pop', rotate popped text
  # Word editing
    ALT-c, ALT-C                 give word initial Cap
    ALT-l, ALT-L                 lowercase word
    CTRL-T                       transpose characters
    ALT-u, ALT-U                 uppercase word
    CTRL-A, HOME_KEY             move cursor to start of line
    CTRL-E, END_KEY              move cursor to end of line
    CTRL-B, LEFT_ARROW_KEY       move cursor left by one character
    CTRL-F, RIGHT_ARROW_KEY      move cursor right by one character
    ALT-f, ALT-F,
    CTRL + RIGHT_ARROW_KEY,
    ALT + RIGHT_ARROW_KEY        move cursor right by one word
    ALT-b, ALT-B,
    CTRL + LEFT_ARROW_KEY,
    aLT + LEFT_ARROW_KEY         move cursor left by one word
  # Basic Editing
    CTRL-C                       abort this line
    CTRL-H/backspace             delete char to left of cursor
    DELETE_KEY                   delete the character under the cursor
    CTRL-D                       delete the character under the cursor
                                 on an empty line, exit the shell
    CTRL-J, CTRL-M/Enter         accept line
    CTRL-L                       clear screen and redisplay line
```

## Compile time switches:
  * prompt_no_history
  * prompt_no_kill
  * prompt_no_completion
  * prompt_no_word_editing
  * prompt_no_preload_buffer
