#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

import styler

type
  Prompt* = object
    text*: Styler       # our copy of the prompt text, edited
    numChars*: int      # chars in promptText
    extraLines*: int    # extra lines (beyond 1) occupied by prompt
    width*: int         # column offset to end of prompt
    rowOffset*: int     # where the cursor is relative to the start of the prompt

proc recalculate*(p: var Prompt, text: Styler, screenWidth: int) =
  p.numChars = 0
  p.extraLines = 0
  p.text = text
  p.width = 0

  var x = 0
  if not text.isNil:
    for c, w in text:
      inc p.numChars
      inc x
      if '\n'.ord == c or x >= screenWidth:
        x = 0
        inc p.extraLines
        p.width = 0
      else:
        inc(p.width, w)

  p.rowOffset = p.extraLines

proc show*(p: Prompt) =
  if not p.text.isNil:
    p.text.show()

proc genNewLine*(p: var Prompt) =
  when not defined(windows):
    # we have to generate our own newline on line wrap on Linux
    if p.width == 0 and p.extraLines > 0:
      stdout.write "\n"

  p.rowOffset = p.extraLines

#[
 when not defined(windows):
   if c == 0 and ctx.gotResize:
     # caught a window resize event
     # now redraw the prompt and line
     ctx.gotResize = false
     pi.promptScreenColumns = terminalWidth()
     # redraw the original prompt with current input
     #dynamicRefresh(pi, buf32, len, pos)
     continue
]#
