#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

when defined(windows):
  import winio
else:
  import posixio

when promptHistory:
  import history

when promptKill:
  import killring

when promptKill:
  type
    KillAction = enum
      killWord
      killToEnd
      killToWhiteSpace

type
  CursorMove = enum
    moveOne
    moveOneWord
    moveToEnd

  Line = object
    data: seq[char32]
    pos: int
    dataLen: int
    prevLen: int
    prompt: Prompt

proc init(x: typedesc[Line]): Line =
  result.data = newSeq[char32](PROMPT_MAX_LINE)

proc isFull(self: Line): bool {.inline.} =
  self.dataLen >= self.data.len

proc atEnd(self: Line): bool {.inline.} =
  self.dataLen == self.pos

proc add(self: var Line, c: char32) {.inline.} =
  self.data[self.pos] = c
  inc self.dataLen
  inc self.pos

proc moveData(self: var Line, dest, src, len: int) =
  moveMem(self.data[dest].addr, self.data[src].addr, sizeof(char32) * len)

proc insertAtCursor(self: var Line, c: char32) =
  self.moveData(self.pos + 1, self.pos, self.dataLen - self.pos)
  self.add(c)

template toOpenArray(self: Line, start, stop: int): auto =
  toOpenArray(cast[ptr UncheckedArray[char32]](self.data[0].unsafeAddr), start, stop - 1)

proc calcColPos(self: Line, len: int): int =
  let width = mk_wcswidth(self.toOpenArray(0, len))
  result = if width == -1: len else: width

proc writeLine(f: File, self: Line) =
  if self.dataLen > 0:
    f.write32(self.data, self.dataLen)

proc clearToEnd(self: var Line) =
  let len = if self.dataLen == 0: 0 else:
    mk_wcswidth(self.toOpenArray(0, self.dataLen))
  if len < self.prevLen:
    stdout.clearToEnd(self.prevLen)
  self.prevLen = len

proc refreshLine(self: var Line, prompt: var Prompt) =
  let
    promptWidth = prompt.width
    screenWidth = terminalWidth()

  #calculate the position of the end of the input line
  var endOfInput = calcScreenPos(promptWidth, 0,
    screenWidth, self.calcColPos(self.dataLen))
  # calculate the desired position of the cursor
  var cursorPos = calcScreenPos(promptWidth, 0,
    screenWidth, self.calcColPos(self.pos))

  var cursorRowMovement = prompt.rowOffset - prompt.extraLines
  if cursorRowMovement > 0:
    # move the cursor up as required
    stdout.cursorUp(cursorRowMovement)

  stdout.hideCursor()

  # position at the end of the prompt, clear to end of screen
  stdout.setCursorXPos(promptWidth)
  self.clearToEnd()

  stdout.writeLine(self)

  when not defined(windows):
    # we have to generate our own newline on line wrap
    if endOfInput.x == 0 and endOfInput.y > 0:
      stdout.write "\n"

  # position the cursor
  cursorRowMovement = endOfInput.y - cursorPos.y
  if cursorRowMovement > 0:
    # move the cursor up as required
    stdout.cursorUp(cursorRowMovement)

  #position the cursor within the line
  stdout.setCursorXPos(cursorPos.x)

  stdout.showCursor()
  stdout.flushFile()

  # remember row for next pass
  prompt.rowOffset = prompt.extraLines + cursorPos.y

template refreshLine(self: var Line) =
  self.refreshLine(self.prompt)

proc moveCursorLeft(self: var Line, move: CursorMove) =
  case move
  of moveOne:
    if self.pos > 0:
      dec self.pos
  of moveOneWord:
    if self.pos > 0:
      self.pos = oneWordLeft(self.pos, self.data)
  of moveToEnd:
    self.pos = 0
  self.refreshLine

proc moveCursorRight(self: var Line, move: CursorMove) =
  case move
  of moveOne:
    if self.pos < self.dataLen:
      inc self.pos
  of moveOneWord:
    if self.pos < self.dataLen:
      self.pos = oneWordRight(self.pos, self.data, self.dataLen)
  of moveToEnd:
    self.pos = self.dataLen
  self.refreshLine

proc addOneChar(self: var Line, c: char32): bool =
  template beepAndReturn() =
    beep()
    return true

  # beep on unknown Ctrl and/or Meta keys
  if (c and (META or CTRL)) != 0: beepAndReturn()

  # buffer is full, beep on new characters
  if self.isFull: beepAndReturn()

  # don't insert control characters
  if isControlChar(c): beepAndReturn()

  if self.atEnd:
    self.add(c)
  else:
    # not at end of buffer, have to move characters to our right
    self.insertAtCursor(c)

  self.refreshLine
  result = true

proc removeOneChar(self: var Line) =
  if self.pos > 0:
    self.moveData(self.pos - 1, self.pos, self.dataLen - self.pos)
    dec self.pos
    dec self.dataLen
    self.refreshLine

proc removeUnderCursor(self: var Line) =
  if self.dataLen > 0 and self.pos < self.dataLen:
    self.moveData(self.pos, self.pos + 1, self.dataLen - self.pos)
    dec self.dataLen
    self.refreshLine

proc resetBuffer(self: var Line) =
  self.pos = 0
  self.dataLen = 0
  self.prevLen = 0

proc getLine(self: Line): string =
  if self.dataLen > 0:
    result = utf32to8(self.data, self.dataLen)
  else:
    result = ""

proc clearScreen(self: var Line) =
  clearScreen()
  self.prompt.show()
  self.prompt.genNewLine()
  self.refreshLine

when promptKill:
  proc killLeft(self: var Line, kill: KillAction): string =
    case kill
    of killWord:
      if self.pos > 0:
        let pos = self.pos
        self.pos = oneWordLeft(self.pos, self.data)
        result = utf32to8(self.toOpenArray(self.pos, pos))
        self.moveData(self.pos, pos, self.dataLen - pos)
        dec(self.dataLen, pos - self.pos)
    of killToEnd:
      if self.pos > 0:
        result = utf32to8(self.toOpenArray(0, self.pos))
        dec(self.dataLen, self.pos)
        self.moveData(0, self.pos, self.dataLen)
        self.pos = 0
    of killToWhiteSpace:
      if self.pos > 0:
        let pos = self.pos
        while self.pos > 0 and self.data[self.pos - 1] == ' '.ord:
          dec self.pos
        while self.pos > 0 and self.data[self.pos - 1] != ' '.ord:
          dec self.pos
        result = utf32to8(self.toOpenArray(self.pos, pos))
        self.moveData(self.pos, pos, self.dataLen - pos)
        dec(self.dataLen, pos - self.pos)
    self.refreshLine

  proc killRight(self: var Line, kill: KillAction): string =
    case kill
    of killWord:
      if self.pos < self.dataLen:
        var pos = oneWordRight(self.pos, self.data, self.dataLen)
        result = utf32to8(self.toOpenArray(self.pos, pos))
        self.moveData(self.pos, pos, self.dataLen - pos)
        dec(self.dataLen, pos - self.pos)
    of killToEnd:
      result = utf32to8(self.toOpenArray(self.pos, self.dataLen))
      self.dataLen = self.pos
    of killToWhiteSpace: discard
    self.refreshLine

  proc insert(self: var Line, text: string): int =
    if text.len == 0: return
    var charCount = wtf8_strlen(text)
    if self.dataLen + charCount >= self.data.len:
      charCount = self.data.len - self.dataLen
    self.moveData(self.pos + charCount, self.pos, self.dataLen - self.pos)
    let written = utf8to32(text, self.data, self.pos, charCount)
    assert(written == charCount)
    inc(self.dataLen, charCount)
    inc(self.pos, charCount)
    self.refreshLine
    result = charCount

  proc insert(self: var Line, text: string, lastSize: int): int =
    if text.len == 0: return lastSize
    var
      truncated = false
      charCount = wtf8_strlen(text)
      lineLength = self.dataLen - lastSize

    if charCount + lineLength > self.data.len:
      charCount = self.data.len - lineLength
      truncated = true

    self.moveData(self.pos + charCount - lastSize, self.pos, self.dataLen - self.pos)
    let written = utf8to32(text, self.data, self.pos - lastSize, charCount)
    assert(written == charCount)

    inc(self.pos, charCount - lastSize)
    inc(self.dataLen, charCount - lastSize)

    if truncated: beep()
    self.refreshLine
    charCount

when promptIncrementalHistorySearch:
  proc clearTextAndPrompt(self: var Line, prompt: var Prompt) =
    for _ in 0 ..< prompt.rowOffset:
      stdout.eraseLine()
      stdout.cursorUp(1)
    stdout.eraseLine()

  proc dynamicRefresh(self: var Line, prompt: var Prompt, screenWidth: int) =
    let promptWidth = prompt.width

    var endOfInput = calcScreenPos(promptWidth, 0,
      screenWidth, self.calcColPos(self.dataLen))

    prompt.show()
    stdout.writeLine(self)
    stdout.flushFile()

    prompt.rowOffset = prompt.extraLines + endOfInput.y

when promptHistory:
  proc update(self: var Line, text: string, prevPos: int = 0) =
    if text.len > 0:
      self.dataLen = text.utf8to32(self.data)
      self.pos = if prevPos != 0: prevPos else: self.dataLen
    else:
      self.pos = 0
      self.dataLen = 0
    self.refreshLine

when promptCompletion:
  proc makeSet(s: string): set[char] {.compileTime.} =
    for c in s: result.incl c

  const breakChars = makeSet(" =+-/\\*?'`&<>;|@{([])}\"")

  proc validChar(self: Line, index: int): bool =
    if index < 0 or index > self.data.len:
      return false
    let c = self.data[index]
    result = (c <= 0x7F) and (c.chr notin breakChars)

  proc breakWord(self: var Line): tuple[head, word, tail: string] =
    var startIndex = self.pos
    if startIndex == self.dataLen:
      dec startIndex

    if not self.validChar(startIndex):
      while startIndex >= 0 and (not self.validChar(startIndex)):
        dec startIndex

    if self.validChar(startIndex):
      while startIndex >= 0 and self.validChar(startIndex):
        dec startIndex

    inc startIndex
    var endIndex = startIndex
    while endIndex < self.dataLen and self.validChar(endIndex):
      inc endIndex

    let itemLength = endIndex - startIndex
    if itemLength == 0: return ("", "", "")

    template toPart(a, b: int): untyped =
      if (b - a) <= 0: "" else: utf32to8(self.toOpenArray(a, b))

    result = (
      head: toPart(0, startIndex),
      word: toPart(startIndex, endIndex),
      tail: toPart(endIndex, self.dataLen)
    )

  proc updateCompletion(self: var Line, text: string) =
    if text.len > 0:
      self.dataLen = text.utf8to32(self.data)
      if self.pos > self.dataLen:
        self.pos = self.dataLen
    else:
      self.pos = 0
      self.dataLen = 0
    self.refreshLine

when promptWordEditing:
  import unicode
  proc findWord(self: var Line) =
    if isAlphaNum(self.data[self.pos]):
      # move to the beginning of the word only if emacs behavior is not set
      when not promptEmacsWordEditing:
        while self.pos > 0 and isAlphaNum(self.data[self.pos - 1]):
          dec self.pos
    else:
      # cursor under something else, move to next word
      while self.pos < self.dataLen and not isAlphaNum(self.data[self.pos]):
        inc self.pos

  proc initialCap(self: var Line) =
    if self.pos < self.dataLen:
      self.findWord()

      if self.pos < self.dataLen and isAlphaNum(self.data[self.pos]):
        if unicode.isAlpha(self.data[self.pos].Rune):
          self.data[self.pos] = toUpper(self.data[self.pos].Rune).char32
        inc self.pos

      while self.pos < self.dataLen and isAlphaNum(self.data[self.pos]):
        if unicode.isAlpha(self.data[self.pos].Rune):
          self.data[self.pos] = toLower(self.data[self.pos].Rune).char32
        inc self.pos
      self.refreshLine

  proc upperCase(self: var Line) =
    if self.pos < self.dataLen:
      self.findWord()

      while self.pos < self.dataLen and isAlphaNum(self.data[self.pos]):
        if unicode.isAlpha(self.data[self.pos].Rune):
          self.data[self.pos] = toUpper(self.data[self.pos].Rune).char32
        inc self.pos
      self.refreshLine

  proc lowerCase(self: var Line) =
    if self.pos < self.dataLen:
      self.findWord()

      while self.pos < self.dataLen and isAlphaNum(self.data[self.pos]):
        if unicode.isAlpha(self.data[self.pos].Rune):
          self.data[self.pos] = toLower(self.data[self.pos].Rune).char32
        inc self.pos
      self.refreshLine

  proc transposeChar(self: var Line) =
    if self.pos > 0 and self.dataLen > 1:
      let pos = if self.pos == self.dataLen: self.pos - 2 else: self.pos - 1
      swap(self.data[pos], self.data[pos + 1])
      if self.pos != self.dataLen: inc self.pos
      self.refreshLine

proc setPrompt(self: var Line, text: Styler, screenWidth: int) =
  self.prompt.recalculate(text, screenWidth)

proc getPrompt(self: Line): Styler =
  self.prompt.text

when promptPreloadBuffer:
  proc preloadBuffer(self: var Line, text: string) =
    self.dataLen = utf8to32(text, self.data)
    self.pos = self.dataLen
