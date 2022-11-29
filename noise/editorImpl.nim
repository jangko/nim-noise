#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

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
      of ESC_KEY, ctrlChar('C'):
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
      let key = self.completeLine()
      self.terminatingKeyStroke = key

      if key <= 0: # return on error/cancel
        return editContinue

      # deliberate fall-through here, so we use the terminating character

when promptIncrementalHistorySearch:
  proc terminatingKey(c: char32): bool =
    const keys = [ctrlChar('P'), ctrlChar('N'), ctrlChar('R'), ctrlChar('S'),
      altChar('<'), PAGE_UP_KEY, altChar('>'), PAGE_DOWN_KEY, altChar('d'), altChar('D'), META + ctrlChar('H'),
      ctrlChar('K'), ctrlChar('U'), ctrlChar('W'), ctrlChar('Y'), altChar('y'), altChar('Y'), altChar('c'),
      altChar('C'), altChar('l'), altChar('L'), ctrlChar('T'), altChar('u'), altChar('U'), ctrlChar('A'), HOME_KEY,
      ctrlChar('E'), END_KEY, ctrlChar('B'), LEFT_ARROW_KEY, ctrlChar('F'), RIGHT_ARROW_KEY, altChar('f'),
      altChar('F'), CTRL + RIGHT_ARROW_KEY, META + RIGHT_ARROW_KEY, altChar('b'), altChar('B'),
      CTRL + LEFT_ARROW_KEY, META + LEFT_ARROW_KEY, 127, DELETE_KEY, ctrlChar('D'),
      ctrlChar('J'), ctrlChar('M'), ctrlChar('L')
    ]
    for x in keys:
      if x == c:
        return true
    result = false

  type
    Search = object
      data: seq[char32]
      dataLen: int
      output: seq[string]
      dirty: bool
      index: int

  proc initSearch(maxLen: int = 50): Search =
    result.dataLen = 0
    result.output = @[]
    result.data = newSeq[char32](maxLen)
    result.dirty = false

  proc addOneChar(self: var Search, c: char32) =
    template beepAndReturn() =
      beep()
      return

    # beep on unknown Ctrl and/or Meta keys
    if (c and (META or CTRL)) != 0: beepAndReturn()

    # buffer is full, beep on new characters
    if self.dataLen >= self.data.len: beepAndReturn()

    # don't insert control characters
    if isControlChar(c): beepAndReturn()

    if self.dataLen < self.data.len:
      self.data[self.dataLen] = c
      inc self.dataLen
      self.dirty = true

  proc removeOneChar(self: var Search) =
    if self.dataLen > 0:
      dec self.dataLen
      self.dirty = true

  proc refreshLine(self: var Noise, search: var Search, prompt: var Prompt) =
    self.line.clearTextAndPrompt(prompt)
    let word = utf32to8(search.data, search.dataLen)

    if search.dirty:
      search.output.setLen(0)
      if word.len > 0:
        self.history.find(word, search.output)

    if search.output.len > 0:
      if search.index >= search.output.len:
        search.index = 0
      if search.index < 0:
        search.index = search.output.len - 1
      self.line.dataLen = utf8to32(search.output[search.index], self.line.data)
    else:
      self.line.dataLen = 0

    let number = if search.output.len == 0: "?" else:
      $(search.index+1) & "/" & $search.output.len

    let text = "[" & number & "]'" & word & "'> "
    prompt.text.update(0, text)
    prompt.recalculate(prompt.text, self.screenWidth)
    self.line.dynamicRefresh(prompt, self.screenWidth)

  proc incrementalHistorySearch(self: var Noise, c: char32): char32 =
    # clear prompt and current buffer
    stdout.hideCursor()
    self.line.clearTextAndPrompt(self.line.prompt)
    let
      prevLine = self.line.getLine()
      prevPos = self.line.pos
    self.line.resetBuffer()

    var search = initSearch()
    var prompt: Prompt
    var styler = newStyler()
    styler.addCmd("[?]''> ")
    prompt.recalculate(styler, self.screenWidth)
    self.line.dynamicRefresh(prompt, self.screenWidth)

    while true:
      var c = readChar()
      c = c.cleanupCtrl
      if c.terminatingKey:
        self.line.clearTextAndPrompt(prompt)
        self.line.prompt.show()
        self.line.prompt.genNewLine()
        if search.output.len > 0:
          self.line.update(search.output[search.index])
        result = c
        break

      case c
      of ctrlChar('I'), DOWN_ARROW_KEY:
        search.dirty = false
        inc search.index
        self.refreshLine(search, prompt)
      of UP_ARROW_KEY:
        search.dirty = false
        dec search.index
        self.refreshLine(search, prompt)
      of ESC_KEY, ctrlChar('C'):
        self.line.clearTextAndPrompt(prompt)
        self.line.prompt.show()
        self.line.prompt.genNewLine()
        self.line.update(prevLine, prevPos)
        result = 0
        break
      of ctrlChar('H'):
        removeOneChar(search)
        self.refreshLine(search, prompt)
      else:
        addOnechar(search, c)
        self.refreshLine(search, prompt)

when promptHistory:
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
      # ctrl-P, recall Prev line in history
      historyAction(moveUp)
    of ctrlChar('N'),  DOWN_ARROW_KEY:
      # ctrl-N, recall next line in history
      historyAction(moveDown)
    of ctrlChar('R'), ctrlChar('S'):
      when promptIncrementalHistorySearch:
        # ctrl-R, reverse history search
        # ctrl-S, forward history search
        if self.history.atBottom() and not self.historyCallRecent:
          self.history.updateLast(self.line.getLine())
        let key = self.incrementalHistorySearch(c)
        self.terminatingKeyStroke = key
        if key <= 0: # return on error/cancel
          return editContinue
      else:
        self.historyCallRecent = false
        result = editNext
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
    self.line.moveCursorRight(moveOneWord)
  of altChar('b'), altChar('B'), CTRL + LEFT_ARROW_KEY, META + LEFT_ARROW_KEY:
    # meta-B, move cursor left by one word
    self.line.moveCursorLeft(moveOneWord)
  else:
    result = editNext

proc basicEditing(self: var Noise, c: char32): EditMode {.cdecl.} =
  case c
  of ESC_KEY:
    # ESC KEY escape
    when defined(esc_exit_editing):
      self.keyType = ktEsc
      result = editAccept
    else:
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
  of ctrlChar('X'):
    # ctrl-X, for custom implementations
    self.keyType = ktCtrlX
    result = editExit
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
