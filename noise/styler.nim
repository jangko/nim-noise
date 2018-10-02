#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

import wtf8, wcwidth, macros, terminal, colors, basic

when defined(windows):
  import winio
else:
  import posixio

type
  StylerAction = enum
    sStyle
    sFgColor
    sBgColor
    sColor
    sReset
    sString
    sRgbMode

  StylerCmd = ref object
    case kind: StylerAction
    of sString: strVal: seq[char32]
    of sStyle: styleVal: set[Style]
    of sFgColor: fgcVal: ForegroundColor
    of sBgColor: bgcVal: BackgroundColor
    of sColor: rgbVal: Color
    of sRgbMode: fgColorMode: bool
    of sReset: nil

  Styler* = ref object
    cmds: seq[StylerCmd]

proc addCmd*(s: Styler, str: string) =
  s.cmds.add StylerCmd(kind: sString, strVal: utf8to32(str))

proc addCmd*(s: Styler, style: Style) =
  s.cmds.add StylerCmd(kind: sStyle, styleVal: {style})

proc addCmd*(s: Styler, style: set[Style]) =
  s.cmds.add StylerCmd(kind: sStyle, styleVal: style)

proc addCmd*(s: Styler, color: ForegroundColor) =
  s.cmds.add StylerCmd(kind: sFgColor, fgcVal: color)

proc addCmd*(s: Styler, color: BackgroundColor) =
  s.cmds.add StylerCmd(kind: sBgColor, bgcVal: color)

proc addCmd*(s: Styler, color: Color) =
  s.cmds.add StylerCmd(kind: sColor, rgbVal: color)

proc addCmd*(s: Styler, cmd: TerminalCmd) =
  case cmd
  of resetStyle:
    s.cmds.add StylerCmd(kind: sReset)
  of fgColor:
    s.cmds.add StylerCmd(kind: sRgbMode, fgColorMode: true)
  of bgColor:
    s.cmds.add StylerCmd(kind: sRgbMode, fgColorMode: false)

proc newStyler*(): Styler =
  new(result)
  result.cmds = @[]

macro style*(s: Styler, m: varargs[typed]): untyped =
  result = newNimNode(nnkStmtList)

  for i in countup(0, m.len - 1):
    let item = m[i]
    result.add(newCall(bindSym"addCmd", s, item))

macro init*(x: typedesc[Styler], m: varargs[typed]): Styler =
  result = newNimNode(nnkStmtList)
  var styler = genSym(nskVar, "styler")
  result.add quote do: ( var `styler` = newStyler() )
  for i in countup(0, m.len - 1):
    let item = m[i]
    result.add(newCall(bindSym"addCmd", styler, item))
  result.add(newCall(bindSym"addCmd", styler, bindSym"resetStyle"))
  result.add quote do: ( `styler` )

proc show*(s: Styler) =
  var mode = true
  for c in s.cmds:
    case c.kind
    of sString: stdout.write32(c.strVal, c.strVal.len)
    of sStyle: stdout.setStyle c.styleVal
    of sFgColor: stdout.setForegroundColor c.fgcVal
    of sBgColor: stdout.setBackgroundColor c.bgcVal
    of sRgbMode: mode = c.fgColorMode
    of sColor:
      if mode: stdout.setForegroundColor c.rgbVal
      else: stdout.setBackgroundColor c.rgbVal
    of sReset: stdout.resetAttributes()
  stdout.flushFile

iterator pairs*(s: Styler): (char32, int) =
  for x in s.cmds:
    if x.kind == sString:
      for c in x.strVal:
        yield (c, mk_wcwidth(c))

proc clear*(s: Styler) =
  s.cmds.setLen(0)

proc update*(s: Styler, index: int, str: string) =
  assert(s.cmds[index].kind == sString)
  s.cmds[index].strVal = utf8to32(str)

proc update*(s: Styler, index: int, style: Style) =
  assert(s.cmds[index].kind == sStyle)
  s.cmds[index].styleVal = {style}

proc update*(s: Styler, index: int, style: set[Style]) =
  assert(s.cmds[index].kind == sStyle)
  s.cmds[index].styleVal = style

proc update*(s: Styler, index: int, color: ForegroundColor) =
  assert(s.cmds[index].kind == sFgColor)
  s.cmds[index].fgcVal = color

proc update*(s: Styler, index: int, color: BackgroundColor) =
  assert(s.cmds[index].kind == sBgColor)
  s.cmds[index].bgcVal = color

proc update*(s: Styler, index: int, color: Color) =
  assert(s.cmds[index].kind == sColor)
  s.cmds[index].rgbVal = color
