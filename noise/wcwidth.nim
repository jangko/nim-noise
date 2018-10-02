#
# This is an implementation of wcwidth() and wcswidth() (defined in
# IEEE Std 1002.1-2001) for Unicode.
#
# http://www.opengroup.org/onlinepubs/007904975/functions/wcwidth.html
# http://www.opengroup.org/onlinepubs/007904975/functions/wcswidth.html
#
# In fixed-width output devices, Latin characters all occupy a single
# "cell" position of equal width, whereas ideographic CJK characters
# occupy two such cells. Interoperability between terminal-line
# applications and (teletype-style) character terminals using the
# UTF-8 encoding requires agreement on which character should advance
# the cursor by how many cell positions. No established formal
# standards exist at present on which Unicode character shall occupy
# how many cell positions on character terminals. These routines are
# a first attempt of defining such behavior based on simple rules
# applied to data provided by the Unicode Consortium.
#
# For some graphical characters, the Unicode standard explicitly
# defines a character-cell width via the definition of the East Asian
# FullWidth (F), Wide (W), Half-width (H), and Narrow (Na) classes.
# In all these cases, there is no ambiguity about which width a
# terminal shall use. For characters in the East Asian Ambiguous (A)
# class, the width choice depends purely on a preference of backward
# compatibility with either historic CJK or Western practice.
# Choosing single-width for these characters is easy to justify as
# the appropriate long-term solution, as the CJK practice of
# displaying these characters as double-width comes from historic
# implementation simplicity (8-bit encoded characters were displayed
# single-width and 16-bit ones double-width, even for Greek,
# Cyrillic, etc.) and not any typographic considerations.
#
# Much less clear is the choice of width for the Not East Asian
# (Neutral) class. Existing practice does not dictate a width for any
# of these characters. It would nevertheless make sense
# typographically to allocate two character cells to characters such
# as for instance EM SPACE or VOLUME INTEGRAL, which cannot be
# represented adequately with a single-width glyph. The following
# routines at present merely assign a single-cell width to all
# neutral characters, in the interest of simplicity. This is not
# entirely satisfactory and should be reconsidered before
# establishing a formal standard in this area. At the moment, the
# decision which Not East Asian (Neutral) characters should be
# represented by double-width glyphs cannot yet be answered by
# applying a simple rule from the Unicode database content. Setting
# up a proper standard for the behavior of UTF-8 character terminals
# will require a careful analysis not only of each Unicode character,
# but also of each presentation form, something the author of these
# routines has avoided to do so far.
#
# http://www.unicode.org/unicode/reports/tr11/
#
# Markus Kuhn -- 2007-05-26 (Unicode 5.0)
#
# Permission to use, copy, modify, and distribute this software
# for any purpose and without fee is hereby granted. The author
# disclaims all warranties with regard to this software.
#
# Latest version: http://www.cl.cam.ac.uk/~mgk25/ucs/wcwidth.c
#
type
  Interval = tuple[first, last: int32]

# auxiliary function for binary search in interval table
proc bisearch(ucs: int32, table: openArray[Interval]): bool =
  var max = table.len - 1
  var min = 0
  var mid: int

  if ucs < table[0].first or ucs > table[max].last:
    return false

  while max >= min:
    mid = (min + max) div 2
    if ucs > table[mid].last:
      min = mid + 1
    elif ucs < table[mid].first:
      max = mid - 1
    else: return true

  result = false

proc mk_wcwidth*(ucs: int32): int =
  const combining = [
    ( 0x0300.int32, 0x036F.int32 ), ( 0x0483.int32, 0x0486.int32 ), ( 0x0488.int32, 0x0489.int32 ),
    ( 0x0591.int32, 0x05BD.int32 ), ( 0x05BF.int32, 0x05BF.int32 ), ( 0x05C1.int32, 0x05C2.int32 ),
    ( 0x05C4.int32, 0x05C5.int32 ), ( 0x05C7.int32, 0x05C7.int32 ), ( 0x0600.int32, 0x0603.int32 ),
    ( 0x0610.int32, 0x0615.int32 ), ( 0x064B.int32, 0x065E.int32 ), ( 0x0670.int32, 0x0670.int32 ),
    ( 0x06D6.int32, 0x06E4.int32 ), ( 0x06E7.int32, 0x06E8.int32 ), ( 0x06EA.int32, 0x06ED.int32 ),
    ( 0x070F.int32, 0x070F.int32 ), ( 0x0711.int32, 0x0711.int32 ), ( 0x0730.int32, 0x074A.int32 ),
    ( 0x07A6.int32, 0x07B0.int32 ), ( 0x07EB.int32, 0x07F3.int32 ), ( 0x0901.int32, 0x0902.int32 ),
    ( 0x093C.int32, 0x093C.int32 ), ( 0x0941.int32, 0x0948.int32 ), ( 0x094D.int32, 0x094D.int32 ),
    ( 0x0951.int32, 0x0954.int32 ), ( 0x0962.int32, 0x0963.int32 ), ( 0x0981.int32, 0x0981.int32 ),
    ( 0x09BC.int32, 0x09BC.int32 ), ( 0x09C1.int32, 0x09C4.int32 ), ( 0x09CD.int32, 0x09CD.int32 ),
    ( 0x09E2.int32, 0x09E3.int32 ), ( 0x0A01.int32, 0x0A02.int32 ), ( 0x0A3C.int32, 0x0A3C.int32 ),
    ( 0x0A41.int32, 0x0A42.int32 ), ( 0x0A47.int32, 0x0A48.int32 ), ( 0x0A4B.int32, 0x0A4D.int32 ),
    ( 0x0A70.int32, 0x0A71.int32 ), ( 0x0A81.int32, 0x0A82.int32 ), ( 0x0ABC.int32, 0x0ABC.int32 ),
    ( 0x0AC1.int32, 0x0AC5.int32 ), ( 0x0AC7.int32, 0x0AC8.int32 ), ( 0x0ACD.int32, 0x0ACD.int32 ),
    ( 0x0AE2.int32, 0x0AE3.int32 ), ( 0x0B01.int32, 0x0B01.int32 ), ( 0x0B3C.int32, 0x0B3C.int32 ),
    ( 0x0B3F.int32, 0x0B3F.int32 ), ( 0x0B41.int32, 0x0B43.int32 ), ( 0x0B4D.int32, 0x0B4D.int32 ),
    ( 0x0B56.int32, 0x0B56.int32 ), ( 0x0B82.int32, 0x0B82.int32 ), ( 0x0BC0.int32, 0x0BC0.int32 ),
    ( 0x0BCD.int32, 0x0BCD.int32 ), ( 0x0C3E.int32, 0x0C40.int32 ), ( 0x0C46.int32, 0x0C48.int32 ),
    ( 0x0C4A.int32, 0x0C4D.int32 ), ( 0x0C55.int32, 0x0C56.int32 ), ( 0x0CBC.int32, 0x0CBC.int32 ),
    ( 0x0CBF.int32, 0x0CBF.int32 ), ( 0x0CC6.int32, 0x0CC6.int32 ), ( 0x0CCC.int32, 0x0CCD.int32 ),
    ( 0x0CE2.int32, 0x0CE3.int32 ), ( 0x0D41.int32, 0x0D43.int32 ), ( 0x0D4D.int32, 0x0D4D.int32 ),
    ( 0x0DCA.int32, 0x0DCA.int32 ), ( 0x0DD2.int32, 0x0DD4.int32 ), ( 0x0DD6.int32, 0x0DD6.int32 ),
    ( 0x0E31.int32, 0x0E31.int32 ), ( 0x0E34.int32, 0x0E3A.int32 ), ( 0x0E47.int32, 0x0E4E.int32 ),
    ( 0x0EB1.int32, 0x0EB1.int32 ), ( 0x0EB4.int32, 0x0EB9.int32 ), ( 0x0EBB.int32, 0x0EBC.int32 ),
    ( 0x0EC8.int32, 0x0ECD.int32 ), ( 0x0F18.int32, 0x0F19.int32 ), ( 0x0F35.int32, 0x0F35.int32 ),
    ( 0x0F37.int32, 0x0F37.int32 ), ( 0x0F39.int32, 0x0F39.int32 ), ( 0x0F71.int32, 0x0F7E.int32 ),
    ( 0x0F80.int32, 0x0F84.int32 ), ( 0x0F86.int32, 0x0F87.int32 ), ( 0x0F90.int32, 0x0F97.int32 ),
    ( 0x0F99.int32, 0x0FBC.int32 ), ( 0x0FC6.int32, 0x0FC6.int32 ), ( 0x102D.int32, 0x1030.int32 ),
    ( 0x1032.int32, 0x1032.int32 ), ( 0x1036.int32, 0x1037.int32 ), ( 0x1039.int32, 0x1039.int32 ),
    ( 0x1058.int32, 0x1059.int32 ), ( 0x1160.int32, 0x11FF.int32 ), ( 0x135F.int32, 0x135F.int32 ),
    ( 0x1712.int32, 0x1714.int32 ), ( 0x1732.int32, 0x1734.int32 ), ( 0x1752.int32, 0x1753.int32 ),
    ( 0x1772.int32, 0x1773.int32 ), ( 0x17B4.int32, 0x17B5.int32 ), ( 0x17B7.int32, 0x17BD.int32 ),
    ( 0x17C6.int32, 0x17C6.int32 ), ( 0x17C9.int32, 0x17D3.int32 ), ( 0x17DD.int32, 0x17DD.int32 ),
    ( 0x180B.int32, 0x180D.int32 ), ( 0x18A9.int32, 0x18A9.int32 ), ( 0x1920.int32, 0x1922.int32 ),
    ( 0x1927.int32, 0x1928.int32 ), ( 0x1932.int32, 0x1932.int32 ), ( 0x1939.int32, 0x193B.int32 ),
    ( 0x1A17.int32, 0x1A18.int32 ), ( 0x1B00.int32, 0x1B03.int32 ), ( 0x1B34.int32, 0x1B34.int32 ),
    ( 0x1B36.int32, 0x1B3A.int32 ), ( 0x1B3C.int32, 0x1B3C.int32 ), ( 0x1B42.int32, 0x1B42.int32 ),
    ( 0x1B6B.int32, 0x1B73.int32 ), ( 0x1DC0.int32, 0x1DCA.int32 ), ( 0x1DFE.int32, 0x1DFF.int32 ),
    ( 0x200B.int32, 0x200F.int32 ), ( 0x202A.int32, 0x202E.int32 ), ( 0x2060.int32, 0x2063.int32 ),
    ( 0x206A.int32, 0x206F.int32 ), ( 0x20D0.int32, 0x20EF.int32 ), ( 0x302A.int32, 0x302F.int32 ),
    ( 0x3099.int32, 0x309A.int32 ), ( 0xA806.int32, 0xA806.int32 ), ( 0xA80B.int32, 0xA80B.int32 ),
    ( 0xA825.int32, 0xA826.int32 ), ( 0xFB1E.int32, 0xFB1E.int32 ), ( 0xFE00.int32, 0xFE0F.int32 ),
    ( 0xFE20.int32, 0xFE23.int32 ), ( 0xFEFF.int32, 0xFEFF.int32 ), ( 0xFFF9.int32, 0xFFFB.int32 ),
    ( 0x10A01.int32, 0x10A03.int32 ), ( 0x10A05.int32, 0x10A06.int32 ), ( 0x10A0C.int32, 0x10A0F.int32 ),
    ( 0x10A38.int32, 0x10A3A.int32 ), ( 0x10A3F.int32, 0x10A3F.int32 ), ( 0x1D167.int32, 0x1D169.int32 ),
    ( 0x1D173.int32, 0x1D182.int32 ), ( 0x1D185.int32, 0x1D18B.int32 ), ( 0x1D1AA.int32, 0x1D1AD.int32 ),
    ( 0x1D242.int32, 0x1D244.int32 ), ( 0xE0001.int32, 0xE0001.int32 ), ( 0xE0020.int32, 0xE007F.int32 ),
    ( 0xE0100.int32, 0xE01EF.int32 )
    ]

  # test for 8-bit control characters
  if ucs == 0: return 0
  if ucs < 32 or (ucs >= 0x7f and ucs < 0xa0): return -1

  # binary search in table of non-spacing characters
  if bisearch(ucs, combining): return 0

  # if we arrive here, ucs is not a combining or C0/C1 control character
  result = 1 +
    (ucs >= 0x1100 and
    (ucs <= 0x115f or                    # Hangul Jamo init. consonants
     ucs == 0x2329 or ucs == 0x232a or
    (ucs >= 0x2e80 and ucs <= 0xa4cf and
     ucs != 0x303f) or                   # CJK ... Yi
    (ucs >= 0xac00 and ucs <= 0xd7a3) or # Hangul Syllables
    (ucs >= 0xf900 and ucs <= 0xfaff) or # CJK Compatibility Ideographs
    (ucs >= 0xfe10 and ucs <= 0xfe19) or # Vertical forms
    (ucs >= 0xfe30 and ucs <= 0xfe6f) or # CJK Compatibility Forms
    (ucs >= 0xff00 and ucs <= 0xff60) or # Fullwidth Forms
    (ucs >= 0xffe0 and ucs <= 0xffe6) or
    (ucs >= 0x20000 and ucs <= 0x2fffd) or
    (ucs >= 0x30000 and ucs <= 0x3fffd))).int

proc mk_wcswidth*(pwcs: openArray[int32]): int =
  for c in pwcs:
    let w = mk_wcwidth(c)
    if w < 0: return -1
    else: inc(result, w)

proc mk_wcwidth_cjk*(ucs: int32): int =
  # sorted list of non-overlapping intervals of East Asian Ambiguous
  # characters, generated by "uniset +WIDTH-A -cat=Me -cat=Mn -cat=Cf c"
  const ambiguous = [
    ( 0x00A1.int32, 0x00A1.int32 ), ( 0x00A4.int32, 0x00A4.int32 ), ( 0x00A7.int32, 0x00A8.int32 ),
    ( 0x00AA.int32, 0x00AA.int32 ), ( 0x00AE.int32, 0x00AE.int32 ), ( 0x00B0.int32, 0x00B4.int32 ),
    ( 0x00B6.int32, 0x00BA.int32 ), ( 0x00BC.int32, 0x00BF.int32 ), ( 0x00C6.int32, 0x00C6.int32 ),
    ( 0x00D0.int32, 0x00D0.int32 ), ( 0x00D7.int32, 0x00D8.int32 ), ( 0x00DE.int32, 0x00E1.int32 ),
    ( 0x00E6.int32, 0x00E6.int32 ), ( 0x00E8.int32, 0x00EA.int32 ), ( 0x00EC.int32, 0x00ED.int32 ),
    ( 0x00F0.int32, 0x00F0.int32 ), ( 0x00F2.int32, 0x00F3.int32 ), ( 0x00F7.int32, 0x00FA.int32 ),
    ( 0x00FC.int32, 0x00FC.int32 ), ( 0x00FE.int32, 0x00FE.int32 ), ( 0x0101.int32, 0x0101.int32 ),
    ( 0x0111.int32, 0x0111.int32 ), ( 0x0113.int32, 0x0113.int32 ), ( 0x011B.int32, 0x011B.int32 ),
    ( 0x0126.int32, 0x0127.int32 ), ( 0x012B.int32, 0x012B.int32 ), ( 0x0131.int32, 0x0133.int32 ),
    ( 0x0138.int32, 0x0138.int32 ), ( 0x013F.int32, 0x0142.int32 ), ( 0x0144.int32, 0x0144.int32 ),
    ( 0x0148.int32, 0x014B.int32 ), ( 0x014D.int32, 0x014D.int32 ), ( 0x0152.int32, 0x0153.int32 ),
    ( 0x0166.int32, 0x0167.int32 ), ( 0x016B.int32, 0x016B.int32 ), ( 0x01CE.int32, 0x01CE.int32 ),
    ( 0x01D0.int32, 0x01D0.int32 ), ( 0x01D2.int32, 0x01D2.int32 ), ( 0x01D4.int32, 0x01D4.int32 ),
    ( 0x01D6.int32, 0x01D6.int32 ), ( 0x01D8.int32, 0x01D8.int32 ), ( 0x01DA.int32, 0x01DA.int32 ),
    ( 0x01DC.int32, 0x01DC.int32 ), ( 0x0251.int32, 0x0251.int32 ), ( 0x0261.int32, 0x0261.int32 ),
    ( 0x02C4.int32, 0x02C4.int32 ), ( 0x02C7.int32, 0x02C7.int32 ), ( 0x02C9.int32, 0x02CB.int32 ),
    ( 0x02CD.int32, 0x02CD.int32 ), ( 0x02D0.int32, 0x02D0.int32 ), ( 0x02D8.int32, 0x02DB.int32 ),
    ( 0x02DD.int32, 0x02DD.int32 ), ( 0x02DF.int32, 0x02DF.int32 ), ( 0x0391.int32, 0x03A1.int32 ),
    ( 0x03A3.int32, 0x03A9.int32 ), ( 0x03B1.int32, 0x03C1.int32 ), ( 0x03C3.int32, 0x03C9.int32 ),
    ( 0x0401.int32, 0x0401.int32 ), ( 0x0410.int32, 0x044F.int32 ), ( 0x0451.int32, 0x0451.int32 ),
    ( 0x2010.int32, 0x2010.int32 ), ( 0x2013.int32, 0x2016.int32 ), ( 0x2018.int32, 0x2019.int32 ),
    ( 0x201C.int32, 0x201D.int32 ), ( 0x2020.int32, 0x2022.int32 ), ( 0x2024.int32, 0x2027.int32 ),
    ( 0x2030.int32, 0x2030.int32 ), ( 0x2032.int32, 0x2033.int32 ), ( 0x2035.int32, 0x2035.int32 ),
    ( 0x203B.int32, 0x203B.int32 ), ( 0x203E.int32, 0x203E.int32 ), ( 0x2074.int32, 0x2074.int32 ),
    ( 0x207F.int32, 0x207F.int32 ), ( 0x2081.int32, 0x2084.int32 ), ( 0x20AC.int32, 0x20AC.int32 ),
    ( 0x2103.int32, 0x2103.int32 ), ( 0x2105.int32, 0x2105.int32 ), ( 0x2109.int32, 0x2109.int32 ),
    ( 0x2113.int32, 0x2113.int32 ), ( 0x2116.int32, 0x2116.int32 ), ( 0x2121.int32, 0x2122.int32 ),
    ( 0x2126.int32, 0x2126.int32 ), ( 0x212B.int32, 0x212B.int32 ), ( 0x2153.int32, 0x2154.int32 ),
    ( 0x215B.int32, 0x215E.int32 ), ( 0x2160.int32, 0x216B.int32 ), ( 0x2170.int32, 0x2179.int32 ),
    ( 0x2190.int32, 0x2199.int32 ), ( 0x21B8.int32, 0x21B9.int32 ), ( 0x21D2.int32, 0x21D2.int32 ),
    ( 0x21D4.int32, 0x21D4.int32 ), ( 0x21E7.int32, 0x21E7.int32 ), ( 0x2200.int32, 0x2200.int32 ),
    ( 0x2202.int32, 0x2203.int32 ), ( 0x2207.int32, 0x2208.int32 ), ( 0x220B.int32, 0x220B.int32 ),
    ( 0x220F.int32, 0x220F.int32 ), ( 0x2211.int32, 0x2211.int32 ), ( 0x2215.int32, 0x2215.int32 ),
    ( 0x221A.int32, 0x221A.int32 ), ( 0x221D.int32, 0x2220.int32 ), ( 0x2223.int32, 0x2223.int32 ),
    ( 0x2225.int32, 0x2225.int32 ), ( 0x2227.int32, 0x222C.int32 ), ( 0x222E.int32, 0x222E.int32 ),
    ( 0x2234.int32, 0x2237.int32 ), ( 0x223C.int32, 0x223D.int32 ), ( 0x2248.int32, 0x2248.int32 ),
    ( 0x224C.int32, 0x224C.int32 ), ( 0x2252.int32, 0x2252.int32 ), ( 0x2260.int32, 0x2261.int32 ),
    ( 0x2264.int32, 0x2267.int32 ), ( 0x226A.int32, 0x226B.int32 ), ( 0x226E.int32, 0x226F.int32 ),
    ( 0x2282.int32, 0x2283.int32 ), ( 0x2286.int32, 0x2287.int32 ), ( 0x2295.int32, 0x2295.int32 ),
    ( 0x2299.int32, 0x2299.int32 ), ( 0x22A5.int32, 0x22A5.int32 ), ( 0x22BF.int32, 0x22BF.int32 ),
    ( 0x2312.int32, 0x2312.int32 ), ( 0x2460.int32, 0x24E9.int32 ), ( 0x24EB.int32, 0x254B.int32 ),
    ( 0x2550.int32, 0x2573.int32 ), ( 0x2580.int32, 0x258F.int32 ), ( 0x2592.int32, 0x2595.int32 ),
    ( 0x25A0.int32, 0x25A1.int32 ), ( 0x25A3.int32, 0x25A9.int32 ), ( 0x25B2.int32, 0x25B3.int32 ),
    ( 0x25B6.int32, 0x25B7.int32 ), ( 0x25BC.int32, 0x25BD.int32 ), ( 0x25C0.int32, 0x25C1.int32 ),
    ( 0x25C6.int32, 0x25C8.int32 ), ( 0x25CB.int32, 0x25CB.int32 ), ( 0x25CE.int32, 0x25D1.int32 ),
    ( 0x25E2.int32, 0x25E5.int32 ), ( 0x25EF.int32, 0x25EF.int32 ), ( 0x2605.int32, 0x2606.int32 ),
    ( 0x2609.int32, 0x2609.int32 ), ( 0x260E.int32, 0x260F.int32 ), ( 0x2614.int32, 0x2615.int32 ),
    ( 0x261C.int32, 0x261C.int32 ), ( 0x261E.int32, 0x261E.int32 ), ( 0x2640.int32, 0x2640.int32 ),
    ( 0x2642.int32, 0x2642.int32 ), ( 0x2660.int32, 0x2661.int32 ), ( 0x2663.int32, 0x2665.int32 ),
    ( 0x2667.int32, 0x266A.int32 ), ( 0x266C.int32, 0x266D.int32 ), ( 0x266F.int32, 0x266F.int32 ),
    ( 0x273D.int32, 0x273D.int32 ), ( 0x2776.int32, 0x277F.int32 ), ( 0xE000.int32, 0xF8FF.int32 ),
    ( 0xFFFD.int32, 0xFFFD.int32 ), ( 0xF0000.int32, 0xFFFFD.int32 ), ( 0x100000.int32, 0x10FFFD.int32 )
  ]

  # binary search in table of non-spacing characters
  if bisearch(ucs, ambiguous): return 2
  result = mk_wcwidth(ucs)

proc mk_wcswidth_cjk*(pwcs: openArray[int32]): int =
  for c in pwcs:
    let w = mk_wcwidth_cjk(c)
    if w < 0: return -1
    else: inc(result, w)
