#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

const
  promptBasic* = not defined(prompt_no_basic)
  promptPrimitives* = not promptBasic
  promptHistory* = not defined(prompt_no_history) and promptBasic
  promptKill* = not defined(prompt_no_kill) and promptBasic
  promptCompletion* = not defined(prompt_no_completion) and promptBasic
  promptWordEditing* = not defined(prompt_no_word_editing) and promptBasic
  promptPreloadBuffer* = not defined(prompt_no_preload_buffer) and promptBasic
  promptIncrementalHistorySearch* = promptHistory and not defined(prompt_no_incremental_history_search)
  promptEmacsWordEditing* = promptWordEditing and defined(prompt_emacs_word_editing)

when promptBasic:
  import noise/[basic, wcwidth, wtf8, styler, prompt], terminal, strutils
  export styler, terminal
  include noise/lineImpl

  type
    KeyType* = enum
      ktNone
      ktCtrlC
      ktCtrlD
      ktCtrlX
      ktEsc

    EditMode = enum
      editOK
      editNext
      editContinue
      editExit
      editAccept
      editFailure

    EditProc = proc(self: var Noise, c: char32): EditMode {.cdecl.}

    CompletionHook* = proc(self: var Noise, text: string): int

    Noise* = object
      when promptHistory:
        history: History
        historyCallRecent: bool
      when promptKill:
        killRing: KillRing
        yankLastSize: int
      when promptCompletion:
        completionHook: CompletionHook
        completionStrings: seq[string]
      when promptPreloadBuffer:
        preloadText: string
        preloadError: string
      terminatingKeyStroke: char32
      keyType: KeyType
      screenWidth: int
      unsupportedTerm: bool
      io: IoCtx
      line: Line
      procs: seq[EditProc]

when promptBasic:
  include noise/editorImpl

  proc init*(x: typedesc[Noise]): Noise =
    result.line = Line.init()
    result.procs = @[]
    result.io = newIoCtx()
    result.screenWidth = terminalWidth()
    result.line.setPrompt(Styler(nil), result.screenWidth)
    result.unsupportedTerm = isUnsupportedTerm()

    when promptCompletion:
      result.procs.add lineCompletion

    when promptKill:
      result.killRing = KillRing.init()
      result.procs.add killAndYank

    when promptHistory:
      result.history = History.init()
      result.procs.add historySearch

    when promptWordEditing:
      result.procs.add wordEditing

    result.procs.add cursorNavigation
    result.procs.add basicEditing

when promptPrimitives:
  when defined(windows):
    import noise/winio, terminal
    export winio.readChar, terminal
  else:
    import noise/posixio, terminal
    export posixio.readChar, terminal

when promptBasic:
  proc keyProcessing(self: var Noise, c: char32): EditMode =
    result = editOK
    for editProc in self.procs:
      let mode = editProc(self, c)
      if mode != editNext:
        result = mode
        break

  proc getInputLine(self: var Noise): bool =
    # The latest history entry is always our current buffer
    when promptHistory:
      self.history.add(self.line.getLine())

    # display the prompt
    self.line.prompt.show()
    self.line.prompt.genNewLine()

    # if there is already text in the buffer, display it first
    if self.line.dataLen > 0:
      self.line.refreshLine

    var c: char32

    self.terminatingKeyStroke = -1

    while true:
      if self.terminatingKeyStroke == -1:
        c = readChar()
      else:
        c = self.terminatingKeyStroke
        self.terminatingKeyStroke = -1

      c = c.cleanupCtrl
      self.keyType = ktNone

      if c <= 0:
        # escape sequence parsing failure
        self.line.refreshLine()
        continue

      let mode = self.keyProcessing(c)

      case mode
      of editOK, editContinue:
        continue
      of editAccept:
        result = true
        break
      else:
        result = false
        break

  proc readFromUnsupportedTerminal(self: var Noise): bool =
    self.line.prompt.show()
    when promptPreloadBuffer:
      if self.preloadText.len == 0:
        self.preloadText = stdin.readLine()
    true

  proc getKeyType*(self: Noise): KeyType =
    self.keyType

  proc getLine*(self: var Noise): string =
    if isAtty(stdin):
      if self.unsupportedTerm:
        when promptPreloadBuffer:
          result = self.preloadText
          self.preloadText = ""
        else:
          result = stdin.readLine()
      else:
        result = self.line.getLine()
    else:
      result = stdin.readLine()

  proc readLine*(self: var Noise): bool =
    when promptPreloadBuffer:
      if self.preloadError.len > 0:
        echo self.preloadError
        self.preloadError = ""

    self.line.resetBuffer()

    if isAtty(stdin):
      if self.unsupportedTerm:
        result = self.readFromUnsupportedTerminal()
      else:
        when promptPreloadBuffer:
          if self.preloadText.len > 0:
            self.line.preloadBuffer(self.preloadText)
            self.preloadText = ""

        discard self.io.enableRawMode()
        result = self.getInputLine()
        stdout.write("\n")
        self.io.disableRawMode()

        when promptHistory:
          self.history.popLast()
    else:
      # input not from a terminal, we should work with piped input, i.e.
      # redirected stdin
      result = true

  proc setPrompt*(self: var Noise, text: Styler) =
    self.line.setPrompt(text, self.screenWidth)

  proc setPrompt*(self: var Noise, text: string) =
    var prompt = newStyler()
    prompt.addCmd(text)
    self.line.setPrompt(prompt, self.screenWidth)

  proc getPrompt*(self: var Noise): Styler =
    self.line.getPrompt()

when promptHistory:
  proc historyAdd*(self: var Noise, line: string) =
    self.history.add line

  proc historySetMaxLen*(self: var Noise, len: int) =
    self.history.setMaxLen(len)

  iterator histories*(self: var Noise): string =
    for c in self.history:
      yield c

  iterator historyPairs*(self: var Noise): (int, string) =
    for i, c in self.history:
      yield (i, c)

  proc historySave*(self: var Noise, fileName: string): bool =
    self.history.save(fileName)

  proc historyLoad*(self: var Noise, fileName: string): bool =
    self.history.load(fileName)

  proc historyClear*(self: var Noise) =
    self.history.clear()

when promptCompletion:
  proc setCompletionHook*(self: var Noise, prc: CompletionHook) =
    self.completionHook = prc

  proc addCompletion*(self: var Noise, text: string) =
    self.completionStrings.add text

when promptPreloadBuffer:
  #  preloadBuffer provides text to be inserted into the command buffer.
  #  the provided text will be processed to be usable and will be used to preload
  #  the input buffer on the next call to prompt()
  #  @param preloadText text to begin with on the next call to prompt()
  proc preloadBuffer*(self: var Noise, preloadText: string) =
    if preloadText.len == 0: return
    var
      temp = ""
      pos = 0

    while pos < preloadText.len:
      var c = preloadText[pos]
      if '\r' == c: continue # silently skip CR
      if c in WhiteSpace:
        # collapse whitespaces into single ' '
        while pos < preloadText.len:
          c = preloadText[pos]
          inc pos
          if c notin WhiteSpace: break
        temp.add ' '
        temp.add c
      else:
        temp.add c
        inc pos

    var truncated = false
    if temp.len > (PROMPT_MAX_LINE - 1):
      truncated = true
      temp.setLen(PROMPT_MAX_LINE - 1)

    self.preloadText = move temp
    if truncated:
      self.preloadError.add " [Edited line: the line length was reduced from "
      self.preloadError.add "$1 to $1\n" % [$self.preloadText.len, $(PROMPT_MAX_LINE - 1)]

when promptKill:
  proc killSetMaxLen*(self: var Noise, len: int) =
    self.killRing.setMaxLen(len)
