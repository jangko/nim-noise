# noise
[![Build Status (Travis)](https://img.shields.io/travis/jangko/nim-noise/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/jangko/nim-noise)
[![Windows build status (Appveyor)](https://img.shields.io/appveyor/ci/jangko/nim-noise/master.svg?label=Windows "Windows build status (Appveyor)")](https://ci.appveyor.com/project/jangko/nim-noise)
![nimble](https://img.shields.io/badge/available%20on-nimble-yellow.svg?style=flat-square)
![license](https://img.shields.io/github/license/citycide/cascade.svg?style=flat-square)

Nim implementation of linenoise command line editor, inspired by
[replxx](https://github.com/AmokHuginnsson/replxx) and
[linenoise-ng](https://github.com/arangodb/linenoise-ng)

## Features
  * Line editing with emacs keybindings
  * History handling
  * Completion
  * Unicode aware
  * Intuitive ESC key sub menu escaping
  * Incremental history search
  * Support multiline editing out of the box
  * Support multiline prompt with color and unicode characters
  * A bunch of compile time switches to select which features you want to turn on/off
  * Support Windows, Linux and Mac OS

## Planned Features
  * Hints(work in progress)
  * Syntax coloring(work in progress)

## API

Basic API:
* proc init*(x: typedesc[Noise]): Noise
* proc getKeyType*(self: Noise): KeyType
* proc getLine*(self: var Noise): string
* proc readLine*(self: var Noise): bool
* proc setPrompt*(self: var Noise, text: Styler)
* proc setPrompt*(self: var Noise, text: string)
* proc getPrompt*(self: var Noise): Styler

History API:
* proc historyAdd*(self: var Noise, line: string)
* proc historySetMaxLen*(self: var Noise, len: int)
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

KillRing API:
* proc killSetMaxLen*(self: var Noise, len: int)

## Examples
```Nim
import noise, strutils

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
       TAB again                 rotate between completion alternatives
       ESC, CTRL-C               undo changes and exit to normal editing
       Other keys                accept completion and resume to normal editing

  # History
    CTRL-P, UP_ARROW_KEY         recall previous line in history
    CTRL-N, DOWN_ARROW_KEY       recall next line in history
    ALT-<, PAGE_UP_KEY           beginning of history
    ALT->, PAGE_DOWN_KEY         end of history

  # Incremental history search
    CTRL-R, CTRL-S               forward/reverse interactive history search
       TAB, DOWN_ARROW_KEY       rotate between history alternatives(+)
       UP_ARROW_KEY              rotate between history alternatives(-)
       ESC, CTRL-C               cancel selection and exit to normal editing
       Other keys                accept selected history

  # Kill and yank
    ALT-D                        kill word to right of cursor
    ALT + Backspace              kill word to left of cursor
    CTRL-K                       kill from cursor to end of line
    CTRL-U                       kill all characters to the left of the cursor
    CTRL-W                       kill to whitespace (not word) to left of cursor
    CTRL-Y                       yank killed text
       ALT-Y                    'yank-pop', rotate popped text

  # Word editing
    ALT-C                        give word initial cap
    ALT-L                        lowercase word
    CTRL-T                       transpose characters
    ALT-U                        uppercase word

  # Cursor navigation
    CTRL-A, HOME_KEY             move cursor to start of line
    CTRL-E, END_KEY              move cursor to end of line
    CTRL-B, LEFT_ARROW_KEY       move cursor left by one character
    CTRL-F, RIGHT_ARROW_KEY      move cursor right by one character
    ALT-F,
    CTRL + RIGHT_ARROW_KEY,
    ALT + RIGHT_ARROW_KEY        move cursor right by one word
    ALT-B,
    CTRL + LEFT_ARROW_KEY,
    ALT + LEFT_ARROW_KEY         move cursor left by one word

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
  Please use `-d:` or `--define:` during build time.
  * prompt_no_history
  * prompt_no_kill
  * prompt_no_completion
  * prompt_no_word_editing
  * prompt_no_preload_buffer
  * prompt_no_incremental_history_search(if you disabled history, this one also disabled)

  Altough you can use `killSetMaxLen` and `historySetMaxLen` at runtime,
  there are compile time options to set them too. e.g. `-d:DefaultHistoryMaxLen=150`

  * DefaultHistoryMaxLen
  * DefaultKillRingMaxLen

## Unicode awareness

On posix OSes, everything is encoded in UTF-8. On Windows, the API dictates UTF-16 usage.
Internally, nim-noise use UTF-32 to encode the text and some homebrew encoding to encode keyboard keys.
Altough this is sound complicated, you as a user will only deal with UTF-8 when interacting with nim-noise.
If your application only use ASCII subset, then you will not to worry about anything.

When you write your completion callback, add retrieve history, preloaded buffer,
you will receive UTF-8 encoded string and give UTF-8/ASCII encoded string too.

## Installation via nimble
> nimble install noise
