#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

import strutils

# handle history related stuff, UTF-8 encoding
type
  History* = object
    maxLen: int
    index: int
    data: seq[string]

const
  # you can use compiler switch -d: or --define:
  # to change this value
  DefaultHistoryMaxLen {.intdefine.} = 100

proc init*(x: typedesc[History]): History =
  result.data = @[]
  result.maxLen = DefaultHistoryMaxLen

proc add*(self: var History, line: string) =
  if self.maxLen == 0: return

  # convert newlines in multi-line code to spaces before storing
  let lineCopy = line.replace('\n', ' ')

  # prevent duplicate history entries
  if self.data.len > 0:
    if self.data[^1] == lineCopy: return

  if self.data.len == self.maxLen:
    self.data.delete(0)

  self.data.add lineCopy
  self.index = self.data.len - 1

proc setMaxLen*(self: var History, maxLen: int) =
  if maxLen < 1: return
  if self.data.len > maxLen:
    self.data.setLen(maxLen)
    self.index = self.data.len - 1
  self.maxLen = maxLen

iterator items*(self: var History): string =
  for h in self.data:
    yield h

iterator pairs*(self: var History): (int, string) =
  for i, h in self.data:
    yield (i, h)

proc save*(self: var History, fileName: string): bool =
  var f: File
  if not f.open(fileName, fmWrite): return false
  for c in self.data:
    f.writeLine(c)
  f.close()

proc load*(self: var History, fileName: string): bool =
  var f: File
  if not f.open(fileName, fmRead): return false
  for line in f.lines:
    if line.len > 0:
      self.add(line)
  f.close()

proc clear*(self: var History) =
  self.data.setLen(0)

proc available*(self: var History): bool {.inline.} =
  self.data.len > 0

proc get*(self: var History): string =
  if self.available():
    result = self.data[self.index]
  else:
    result = ""

proc moveUp*(self: var History) =
  if self.available():
    dec self.index
    if self.index < 0: self.index = self.data.len - 1

proc moveDown*(self: var History) =
  if self.available():
    inc self.index
    if self.index >= self.data.len: self.index = 0

proc moveTop*(self: var History) =
  if self.available():
    self.index = 0

proc moveBottom*(self: var History) =
  if self.available():
    self.index = self.data.len - 1

proc commonPrefixSearch*(self: var History, prefix: string, back: bool): bool =
  if prefix.len == 0: return false
  if back:
    for i in countDown(self.data.len-1, 0):
      if equalMem(self.data[i][0].addr, prefix[0].unsafeAddr, prefix.len):
        self.index = i
        return true
  else:
    for i, c in self.data:
      if equalMem(c[0].unsafeAddr, prefix[0].unsafeAddr, prefix.len):
        self.index = i
        return true

proc find*(self: var History, text: string, output: var seq[string]) =
  for c in self.data:
    if c.find(text) != -1:
      output.add c

proc popLast*(self: var History) =
  if self.available():
    discard self.data.pop()
    if self.index >= self.data.len:
      self.index = self.data.len - 1

proc atBottom*(self: History): bool =
  result = self.index == self.data.len - 1

proc updateLast*(self: var History, text: string) =
  if self.available():
    self.data[^1] = text
  else:
    self.data.add text
