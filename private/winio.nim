#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

import terminal, winlean, wtf8, basic, strutils, os

type
  SHORT = int16
  COORD = object
    x: SHORT
    y: SHORT

  SMALL_RECT = object
    left: SHORT
    top: SHORT
    right: SHORT
    bottom: SHORT

  CONSOLE_SCREEN_BUFFER_INFO = object
    dwSize: COORD
    dwCursorPosition: COORD
    wAttributes: int16
    srWindow: SMALL_RECT
    dwMaximumWindowSize: COORD

proc writeConsole(hConsole: HANDLE, lpBuffer: pointer, len: DWORD,
  written: var DWORD, reserved: pointer): WINBOOL
  {.stdcall, dynlib: "kernel32", importc: "WriteConsoleW".}

proc getConsoleMode(hConsoleHandle: HANDLE, dwMode: var DWORD): WINBOOL {.
  stdcall, dynlib: "kernel32", importc: "GetConsoleMode".}

proc setConsoleMode(hConsoleHandle: HANDLE, dwMode: DWORD): WINBOOL {.
  stdcall, dynlib: "kernel32", importc: "SetConsoleMode".}

proc getConsoleScreenBufferInfo(hConsoleOutput: HANDLE,
    lpConsoleScreenBufferInfo: ptr CONSOLE_SCREEN_BUFFER_INFO): WINBOOL{.stdcall,
    dynlib: "kernel32", importc: "GetConsoleScreenBufferInfo".}

proc fillConsoleOutputCharacter(hConsoleOutput: Handle, cCharacter: char,
                                nLength: DWORD, dwWriteCoord: Coord,
                                lpNumberOfCharsWritten: var DWORD): WINBOOL{.
      stdcall, dynlib: "kernel32", importc: "FillConsoleOutputCharacterA".}

const
  KEY_EVENT = 1

  VK_MENU   = 18
  VK_LEFT   = 37
  VK_UP     = 38
  VK_RIGHT  = 39
  VK_DOWN   = 40

  VK_END    = 35
  VK_HOME   = 36
  VK_DELETE = 46
  VK_PRIOR  = 33
  VK_NEXT   = 34

  LEFT_ALT_PRESSED  = 0x0002
  LEFT_CTRL_PRESSED = 0x0008
  RIGHT_ALT_PRESSED  = 0x0001
  RIGHT_CTRL_PRESSED = 0x0004

  ENABLE_LINE_INPUT = 0x0002
  ENABLE_PROCESSED_INPUT = 0x0001
  ENABLE_ECHO_INPUT = 0x0004

type
  IoCtx* = ref object
    consoleIn: HANDLE
    consoleOut: HANDLE
    consoleMode: DWORD

proc newIoCtx*(): IoCtx =
  new(result)

proc enableRawMode*(ctx: IoCtx): bool =
  if ctx.consoleIn == HANDLE(0):
    ctx.consoleIn = getStdHandle(STD_INPUT_HANDLE)
    ctx.consoleOut = getStdHandle(STD_OUTPUT_HANDLE)

    discard getConsoleMode(ctx.consoleIn, ctx.consoleMode)
    let mode = ctx.consoleMode and not (ENABLE_LINE_INPUT or
      ENABLE_ECHO_INPUT or ENABLE_PROCESSED_INPUT)
    discard setConsoleMode(ctx.consoleIn, mode)
  result = true

proc disableRawMode*(ctx: IoCtx) =
  discard setConsoleMode(ctx.consoleIn, ctx.consoleMode)
  ctx.consoleIn = 0
  ctx.consoleOut = 0

proc readChar*(): char32 =
  let fd = getStdHandle(STD_INPUT_HANDLE)
  var
    rec = KEY_EVENT_RECORD()
    numRead: cint
    modifierKeys = 0.char32
    highSurrogate = 0

  while true:
    doAssert(waitForSingleObject(fd, INFINITE) == WAIT_OBJECT_0)
    doAssert(readConsoleInput(fd, rec.addr, 1, numRead.addr) != 0)
    if rec.eventType != KEY_EVENT: continue

    when defined(DEBUG_KEYBOARD):
      var ctrlKey = ""
      if (rec.dwControlKeyState and LEFT_CTRL_PRESSED) != 0: ctrlKey.add " L-Ctrl"
      if (rec.dwControlKeyState and RIGHT_CTRL_PRESSED) != 0: ctrlKey.add " R-Ctrl"
      if (rec.dwControlKeyState and LEFT_ALT_PRESSED) != 0: ctrlKey.add " L-Alt"
      if (rec.dwControlKeyState and RIGHT_ALT_PRESSED) != 0: ctrlKey.add " R-Alt"
      echo "Unicode character $1, repeat count $2, virtual keycode $3, virtual scancode $4, key $5$6" % [
        toHex(rec.uChar, 4), $rec.wRepeatCount, toHex(rec.wVirtualKeyCode, 4),
        toHex(rec.wVirtualScanCode, 4), if rec.bKeyDown == 1: "down" else: "up", ctrlKey]

    # Windows provides for entry of characters that are not on your keyboard by
    # sending the Unicode characters as a "key up" with virtual keycode 0x12
    # (VK_MENU == Alt key) ...
    # accept these characters, otherwise only process characters on "key down"
    if rec.bKeyDown == 0 and rec.wVirtualKeyCode != VK_MENU: continue
    modifierKeys = 0

    # AltGr is encoded as ( LEFT_CTRL_PRESSED | RIGHT_ALT_PRESSED ), so don't
    # treat this combination as either CTRL or META we just turn off those two bits,
    # so it is still possible to combine CTRL and/or META with an AltGr key by using
    # right-Ctrl and/or left-Alt
    const altGr = LEFT_CTRL_PRESSED or RIGHT_ALT_PRESSED
    if (rec.dwControlKeyState and altGr) == altGr:
      rec.dwControlKeyState = rec.dwControlKeyState and not altGr

    if (rec.dwControlKeyState and
      (RIGHT_CTRL_PRESSED or LEFT_CTRL_PRESSED)) != 0:
      modifierKeys = modifierKeys or CTRL

    if (rec.dwControlKeyState and
      (RIGHT_ALT_PRESSED or LEFT_ALT_PRESSED)) != 0:
      modifierKeys = modifierKeys or META

    var key = int(rec.uChar) and 0xFFFF
    if key == 0:
      case rec.wVirtualKeyCode:
      of VK_LEFT: return modifierKeys or LEFT_ARROW_KEY
      of VK_RIGHT: return modifierKeys or RIGHT_ARROW_KEY
      of VK_UP: return modifierKeys or UP_ARROW_KEY
      of VK_DOWN: return modifierKeys or DOWN_ARROW_KEY
      of VK_DELETE: return modifierKeys or DELETE_KEY
      of VK_HOME: return modifierKeys or HOME_KEY
      of VK_END: return modifierKeys or END_KEY
      of VK_PRIOR: return modifierKeys or PAGE_UP_KEY
      of VK_NEXT: return modifierKeys or PAGE_DOWN_KEY
      else: continue
        # in raw mode, ReadConsoleInput shows shift, ctrl ...
        #  ... ignore them
    elif key >= 0xD800 and key <= 0xDBFF:
      highSurrogate = key - 0xD800
      continue
    else:
      # we got a real character, return it
      if key >= 0xDC00 and key <= 0xDFFF:
        key = key - 0xDC00
        key = key or (highSurrogate shl 10)
        key = key + 0x10000
      key = key or modifierKeys
      highSurrogate = 0
      result = key.char32
      break

proc write32*(f: File, data: seq[char32], len: int) =
  var temp = utf32to16(data, len)
  let fd = getStdHandle(STD_OUTPUT_HANDLE)
  var written: DWORD
  discard writeConsole(fd, temp[0].addr, temp.len.DWORD, written, nil)

proc getCursorPos(): Coord =
  let h = getStdHandle(STD_OUTPUT_HANDLE)
  var scrbuf: CONSOLESCREENBUFFERINFO
  if getConsoleScreenBufferInfo(h, addr(scrbuf)) == 0:
    raiseOSError(osLastError())
  var origin = scrbuf.dwCursorPosition
  result = Coord(x: origin.x, y: origin.y)

proc clearToEnd*(f: File, len: int) =
  let h = getStdHandle(STD_OUTPUT_HANDLE)
  let c = getCursorPos()
  var count: DWORD
  discard h.fillConsoleOutputCharacter(' ', len.DWORD, c, count)
  setCursorPos(c.x, c.y)

proc clearScreen*() =
  var
    coord = Coord(x: 0, y: 0)
    scrbuf: CONSOLESCREENBUFFERINFO
    screenHandle = getStdHandle(STD_OUTPUT_HANDLE)
    count: DWORD

  discard getConsoleScreenBufferInfo(screenHandle, scrbuf.addr)
  setCursorPos(coord.x, coord.y)
  discard fillConsoleOutputCharacter(screenHandle, ' ',
    DWORD(scrbuf.dwSize.x) * DWORD(scrbuf.dwSize.y), coord, count)
