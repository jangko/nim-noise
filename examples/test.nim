import noise, strutils

proc printHelp() =
  echo "# Completion"
  echo "  CTRL-I/TAB                   activates completion"
  echo "     TAB again                 rotate between completion alternatives"
  echo "     ESC, CTRL-C               undo changes and exit to normal editing"
  echo "     Other keys                accept completion and resume to normal editing"
  echo ""
  echo "# History"
  echo "  CTRL-P, UP_ARROW_KEY         recall previous line in history"
  echo "  CTRL-N, DOWN_ARROW_KEY       recall next line in history"
  echo "  ALT-<, PAGE_UP_KEY           beginning of history"
  echo "  ALT->, PAGE_DOWN_KEY         end of history"
  echo ""
  echo "# Incremental history search"
  echo "  CTRL-R, CTRL-S               forward/reverse interactive history search"
  echo "     TAB, DOWN_ARROW_KEY       rotate between history alternatives(+)"
  echo "     UP_ARROW_KEY              rotate between history alternatives(-)"
  echo "     ESC, CTRL-C               cancel selection and exit to normal editing"
  echo "     Other keys                accept selected history"
  echo ""
  echo "# Kill and Yank"
  echo "  ALT-D:                       kill word to right of cursor"
  echo "  ALT + Backspace:             kill word to left of cursor"
  echo "  CTRL-K                       kill from cursor to end of line"
  echo "  CTRL-U                       kill all characters to the left of the cursor"
  echo "  CTRL-W                       kill to whitespace (not word) to left of cursor"
  echo "  CTRL-Y                       yank killed text"
  echo "     ALT-Y                     'yank-pop', rotate popped text"
  echo ""
  echo "# Word editing"
  echo "  ALT-C                        give word initial Cap"
  echo "  ALT-L                        lowercase word"
  echo "  CTRL-T                       transpose characters"
  echo "  ALT-U                        uppercase word"
  echo ""
  echo "# Cursor navigation"
  echo "  CTRL-A, HOME_KEY             move cursor to start of line"
  echo "  CTRL-E, END_KEY              move cursor to end of line"
  echo "  CTRL-B, LEFT_ARROW_KEY       move cursor left by one character"
  echo "  CTRL-F, RIGHT_ARROW_KEY      move cursor right by one character"
  echo "  ALT-F,"
  echo "  CTRL + RIGHT_ARROW_KEY,"
  echo "  ALT + RIGHT_ARROW_KEY        move cursor right by one word"
  echo "  ALT-B,"
  echo "  CTRL + LEFT_ARROW_KEY,"
  echo "  ALT + LEFT_ARROW_KEY         move cursor left by one word"
  echo ""
  echo "# Basic Editing"
  echo "  CTRL-C                       abort this line"
  echo "  CTRL-H/backspace             delete char to left of cursor"
  echo "  DELETE_KEY                   delete the character under the cursor"
  echo "  CTRL-D                       delete the character under the cursor"
  echo "                               on an empty line, exit the shell"
  echo "  CTRL-J, CTRL-M/Enter         accept line"
  echo "  CTRL-L                       clear screen and redisplay line"

proc main() =
  var noise = Noise.init()

  let prompt = Styler.init(fgRed, "Red ", fgGreen, "苹果\nSecond Row> ")
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