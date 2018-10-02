#
#           nim-noise
#        (c) Copyright 2018 Andri Lim
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

import deques, math

type
  KillRingAction* = enum
    actionOther
    actionKill
    actionYank

  KillRing* = object
    maxLen: int
    index: int
    data: Deque[string]
    lastAct: KillRingAction

const
  # you can use compiler switch -d: or --define:
  # to change this value
  DefaultKillRingMaxLen {.intdefine.} = 10

proc init*(x: typedesc[KillRing]): KillRing =
  result.maxLen  = DefaultKillRingMaxLen
  result.data    = initDeque[string](nextPowerOfTwo(result.maxLen))
  result.lastAct = actionOther

proc setMaxLen*(self: var KillRing, maxLen: int) =
  if maxLen < 1: return
  self.maxLen = maxLen
  while self.data.len >= maxLen:
    self.data.popLast
  if self.index >= self.data.len:
    self.index = self.data.len - 1

proc kill*(self: var KillRing, killedText: string, forward: bool) =
  if killedText.len == 0: return

  if self.lastAct == actionKill and self.data.len > 0:
    if forward:
      self.data[0] = self.data[0] & killedText
    else:
      self.data[0] = killedText & self.data[0]
  else:
    if self.data.len < self.maxLen:
      self.data.addFirst(killedText)
    else:
      self.data.popLast
      self.data.addFirst(killedText)
    self.index = 0
  self.lastAct = actionKill

proc available*(self: KillRing): bool {.inline.} =
  self.data.len > 0

proc yank*(self: var KillRing): string =
  if self.available():
    result = self.data[self.index]
  else:
    result = ""
  self.lastAct = actionYank

proc yankPop*(self: var KillRing): string =
  if self.available():
    inc self.index
    if self.index == self.data.len:
      self.index = 0
    result = self.data[self.index]
  else:
    result = ""
  self.lastAct = actionYank

proc lastAction*(self: KillRing): KillRingAction {.inline.} =
  self.lastAct

proc lastAction*(self: var KillRing, action: KillRingAction) {.inline.} =
  self.lastAct = action

proc resetAction*(self: var KillRing) {.inline.} =
  self.lastAct = actionOther
