when promptCompletion:
  proc completeLine(self: var Noise): char32 =
    let line = self.line.getLine()
    let parts = self.line.breakWord()
    if parts.word.len == 0: return 0

    discard self.completionHook(self, parts.word)
    if self.completionStrings.len == 0: return 0

    var index = 0
    self.line.updateCompletion(parts.head &
      self.completionStrings[index] & parts.tail)

    while true:
      var c = readChar()
      c = c.cleanupCtrl
      case c
      of ctrlChar('I'):
        inc index
        if index >= self.completionStrings.len:
          index = 0
        self.line.updateCompletion(parts.head &
          self.completionStrings[index] & parts.tail)
      of ESC_KEY:
        self.line.updateCompletion(line)
        result = 0
        break
      else:
        result = c
        break

    self.completionStrings.setLen(0)

  proc lineCompletion(self: var Noise, c: char32): EditMode {.cdecl.} =
    result = editNext

    # ctrl-I/tab, command completion, needs to be before switch statement
    if c == ctrlChar('I') and self.completionHook != nil:
      # completeLine does the actual completion and replacement
      var c = self.completeLine()
      self.terminatingKeyStroke = c

      if c <= 0: # return on error
        return editContinue

      # deliberate fall-through here, so we use the terminating character

when promptHistory:
  proc incrementalHistorySearch(self: var Noise, c: char32): char32 =
    discard

  proc historySearch(self: var Noise, c: char32): EditMode {.cdecl.} =
    template historyAction(cmd: untyped): untyped =
      if self.history.available:
        if self.historyCallRecent: self.history.cmd
        if self.history.atBottom() and not self.historyCallRecent:
          self.history.updateLast(self.line.getLine())
          self.history.cmd
        self.line.update self.history.get()
        self.historyCallRecent = true

    case c
    of ctrlChar('P'), UP_ARROW_KEY:
      # ctrl-N, recall next line in history
      historyAction(moveUp)
    of ctrlChar('N'),  DOWN_ARROW_KEY, :
      # ctrl-P, recall Prev line in history
      historyAction(moveDown)
    of ctrlChar('R'), ctrlChar('S'):
      # ctrl-R, reverse history search
      # ctrl-S, forward history search
      if self.history.atBottom() and not self.historyCallRecent:
        self.history.updateLast(self.line.getLine())
      self.terminatingKeyStroke = self.incrementalHistorySearch(c)
    of altChar('<'), PAGE_UP_KEY:
      # meta-<, beginning of history
      # Page Up, beginning of history
      historyAction(moveTop)
    of altChar('>'), PAGE_DOWN_KEY:
      # meta->, end of history
      # Page Down, end of history
      historyAction(moveBottom)
    else:
      self.historyCallRecent = false
      result = editNext

when promptKill:
  proc killAndYank(self: var Noise, c: char32): EditMode {.cdecl.} =
    case c
    of altChar('d'), altChar('D'):
      # meta-D, kill word to right of cursor
      self.killRing.kill self.line.killRight(killWord), true
    of META + ctrlChar('H'):
      # meta-Backspace, kill word to left of cursor
      self.killRing.kill self.line.killLeft(killWord), false
    of ctrlChar('K'):
      # ctrl-K, kill from cursor to end of line
      self.killRing.kill self.line.killRight(killToEnd), true
    of ctrlChar('U'):
      # ctrl-U, kill all characters to the left of the cursor
      self.killRing.kill self.line.killLeft(killToEnd), false
    of ctrlChar('W'):
      # ctrl-W, kill to whitespace (not word) to left of cursor
      self.killRing.kill self.line.killLeft(killToWhiteSpace), false
    of ctrlChar('Y'):
      # ctrl-Y, yank killed text
      self.yankLastSize = self.line.insert self.killRing.yank()
    of altChar('y'), altChar('Y'):
      # meta-Y, 'yank-pop', rotate popped text
      if self.killRing.lastAction == actionYank:
        self.yankLastSize = self.line.insert(self.killRing.yankPop(), self.yankLastSize)
      else:
        beep()
    else:
      self.killRing.resetAction()
      result = editNext

when promptWordEditing:
  proc wordEditing(self: var Noise, c: char32): EditMode {.cdecl.} =
    case c
    of altChar('c'), altChar('C'):
      # meta-C, give word initial Cap
      self.line.initialCap
    of altChar('l'), altChar('L'):
      # meta-L, lowercase word
      self.line.lowerCase
    of ctrlChar('T'):
      # ctrl-T, transpose characters
      self.line.transposeChar
    of altChar('u'), altChar('U'):
      # meta-U, uppercase word
      self.line.upperCase
    else:
      result = editNext

proc cursorNavigation(self: var Noise, c: char32): EditMode {.cdecl.} =
  case c
  of ctrlChar('A'), HOME_KEY:
    # ctrl-A, move cursor to start of line
    self.line.moveCursorLeft(moveToEnd)
  of ctrlChar('E'), END_KEY:
    # ctrl-E, move cursor to end of line
    self.line.moveCursorRight(moveToEnd)
  of ctrlChar('B'), LEFT_ARROW_KEY:
    # ctrl-B, move cursor left by one character
    self.line.moveCursorLeft(moveOne)
  of ctrlChar('F'), RIGHT_ARROW_KEY:
    # ctrl-F, move cursor right by one character
    self.line.moveCursorRight(moveOne)
  of altChar('f'), altChar('F'), CTRL + RIGHT_ARROW_KEY, META + RIGHT_ARROW_KEY:
    # meta-F, move cursor right by one word
    self.line.moveCursorLeft(moveOneWord)
  of altChar('b'), altChar('B'), CTRL + LEFT_ARROW_KEY, META + LEFT_ARROW_KEY:
    # meta-B, move cursor left by one word
    self.line.moveCursorRight(moveOneWord)
  else:
    result = editNext

proc basicEditing(self: var Noise, c: char32): EditMode {.cdecl.} =
  case c
  of ESC_KEY:
    # ESC KEY escape
    beep()
  of ctrlChar('C'):
    # ctrl-C, abort this line
    self.line.moveCursorRight(moveToEnd)
    stdout.write("^C")
    self.keyType = ktCtrlC
    result = editExit
  of ctrlChar('H'):
    # backspace/ctrl-H, delete char to left of cursor
    self.line.removeOneChar()
  of 127, DELETE_KEY:
    # DEL, delete the character under the cursor
    self.line.removeUnderCursor()
  of ctrlChar('D'):
    # ctrl-D, delete the character under the cursor
    # on an empty line, exit the shell
    if self.line.dataLen > 0:
      self.line.removeUnderCursor()
    else:
      result = editExit
    self.keyType = ktCtrlD
  of ctrlChar('J'), ctrlChar('M'):
    # ctrl-J/linefeed/newline, accept line
    # ctrl-M/return/enter

    # we need one last refresh with the cursor at the end of the line
    # so we don't display the next prompt over the Prev input line
    self.line.moveCursorRight(moveToEnd) # pass len as pos for EOL
    result = editAccept
  of ctrlChar('L'):
    # ctrl-L, clear screen and redisplay line
    self.line.clearScreen()
  else:
    if self.line.addOnechar(c):
      result = editContinue
    else:
      result = editFailure
