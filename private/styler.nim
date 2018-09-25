import wtf8, wcwidth, macros, terminal, colors, basic

when defined(windows):
  import winio
else:
  import posixio

type
  StylerAction = enum
    sStyle
    sFGColor
    sBGColor
    sColor
    sReset
    sString
    sRgbMode

  StylerItem = ref object
    case kind: StylerAction
    of sString: strVal: seq[char32]
    of sStyle: styleVal: set[Style]
    of sFGColor: fgcVal: ForegroundColor
    of sBGColor: bgcVal: BackgroundColor
    of sColor: rgbVal: Color
    of sRgbMode: fgColorMode: bool
    of sReset: nil

  Styler* = ref object
    cmds: seq[StylerItem]

proc addCmd*(s: Styler, str: string) =
  s.cmds.add StylerItem(kind: sString, strVal: utf8to32(str))

proc addCmd*(s: Styler, style: Style) =
  s.cmds.add StylerItem(kind: sStyle, styleVal: {style})

proc addCmd*(s: Styler, style: set[Style]) =
  s.cmds.add StylerItem(kind: sStyle, styleVal: style)

proc addCmd*(s: Styler, color: ForegroundColor) =
  s.cmds.add StylerItem(kind: sFGColor, fgcVal: color)

proc addCmd*(s: Styler, color: BackgroundColor) =
  s.cmds.add StylerItem(kind: sBGColor, bgcVal: color)

proc addCmd*(s: Styler, color: Color) =
  s.cmds.add StylerItem(kind: sColor, rgbVal: color)

proc addCmd*(s: Styler, cmd: TerminalCmd) =
  case cmd
  of resetStyle:
    s.cmds.add StylerItem(kind: sReset)
  of fgColor:
    s.cmds.add StylerItem(kind: sRgbMode, fgColorMode: true)
  of bgColor:
    s.cmds.add StylerItem(kind: sRgbMode, fgColorMode: false)

proc initStyler*(): Styler =
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
  result.add quote do: ( var `styler` = initStyler() )
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
    of sFGColor: stdout.setForegroundColor c.fgcVal
    of sBGColor: stdout.setBackgroundColor c.bgcVal
    of sRgbMode: mode = c.fgColorMode
    of sColor:
      if mode: stdout.setForegroundColor c.rgbVal
      else: stdout.setBackgroundColor c.rgbVal
    of sReset: stdout.resetAttributes()
  stdout.flushFile

proc calcLen*(s: Styler): int =
  for c in s.cmds:
    if c.kind == sString:
      inc(result, c.strVal.len)

iterator pairs*(s: Styler): (char32, int) =
  for x in s.cmds:
    if x.kind == sString:
      for c in x.strVal:
        yield (c, mk_wcwidth(c))
