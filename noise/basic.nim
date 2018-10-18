#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

import wtf8, wcwidth, os, strutils, unicode

type
  char32* = int32
  char16* = int16
  char8*  = uint8

const
  META* = 0x40000000 # Meta key combination
  CTRL* = 0x20000000 # Ctrl key combination

  # Special keys
  ESC_KEY*         = 0x1B
  UP_ARROW_KEY*    = 0x10200000
  DOWN_ARROW_KEY*  = 0x10400000
  RIGHT_ARROW_KEY* = 0x10600000
  LEFT_ARROW_KEY*  = 0x10800000
  HOME_KEY*        = 0x10A00000
  END_KEY*         = 0x10C00000
  DELETE_KEY*      = 0x10E00000
  PAGE_UP_KEY*     = 0x11000000
  PAGE_DOWN_KEY*   = 0x11200000

  PROMPT_MAX_LINE* = 4096

template ctrlChar*(x: char): int =
  ord(x) - 0x40

template altChar*(x: char): int =
  META + ord(x)

# convert {CTRL + 'A'}, {CTRL + 'a'} and {CTRL + ctrlChar( 'A' )} into
# ctrlChar( 'A' ),  leave META alone
proc cleanupCtrl*(c: char32): char32 =
  result = c
  if (c and CTRL) != 0:
    let d = c and 0x1FF
    if d >= 'a'.ord and d <= 'z'.ord:
      result = (c + ('a'.ord - ctrlChar('A'))) and not CTRL
    if d >= 'A'.ord and d <= 'Z'.ord:
      result = (c + ('A'.ord - ctrlChar('A'))) and not CTRL
    if d >= ctrlChar('A') and d <= ctrlChar('Z'):
      result = c and not CTRL

proc isControlChar*(testChar: char32): bool =
  result = (testChar < ' '.ord) or                 # C0 controls
           (testChar >= 0x7F and testChar <= 0x9F) # DEL and C1 controls

proc beep*() =
  stderr.write("\x07") # ctrl-G == bell/beep
  stderr.flushFile()

# Calculate a new screen position given a starting position, screen width and
# character count
# @param x             initial x position (zero-based)
# @param y             initial y position (zero-based)
# @param screenColumns screen column count
# @param charCount     character positions to advance
proc calcScreenPos*(x, y, screenColumns, charCount: int): tuple[x, y: int] =
  var
    x = x
    y = y
    xOut = x
    yOut = y

  var charsRemaining = charCount
  while charsRemaining > 0:
    let charsThisRow = if (x + charsRemaining < screenColumns):
      charsRemaining else: screenColumns - x

    xOut = x + charsThisRow
    yOut = y
    charsRemaining -= charsThisRow
    x = 0
    inc y

  if xOut == screenColumns:
    # we have to special-case line wrap
    xOut = 0
    inc yOut

  result = (xOut, yOut)

proc isAlphaNum*(c: char32): bool =
  unicode.isAlpha(c.Rune) or (c >= '0'.ord and c <= '9'.ord)

proc oneWordLeft*(pos: int, data: seq[char32]): int =
  result = pos
  while result > 0 and not isAlphaNum(data[result - 1]):
    dec result
  while result > 0 and isAlphaNum(data[result - 1]):
    dec result

proc oneWordRight*(pos: int, data: seq[char32], len: int): int =
  result = pos
  while result < len and not isAlphaNum(data[result]):
    inc result
  while result < len and isAlphaNum(data[result]):
    inc result

proc isUnsupportedTerm*(): bool =
  const
    unsupportedTerm = ["dumb", "cons25", "emacs"]
  let
    term = getEnv("TERM")
  if term.len == 0: return false
  for c in unsupportedTerm:
    if cmpIgnoreCase(term, c) == 0:
      return true
