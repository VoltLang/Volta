// Copyright © 2013-2015, Bernard Helyer.
// See copyright notice in src/volt/licence.d (BOOST ver 1.0)
module vrt.vacuum.utf;

import core.exception: MalformedUTF8Exception;


private enum ONE_BYTE_MASK                   = 0x80;
private enum TWO_BYTE_MASK                   = 0xE0;
private enum TWO_BYTE_RESULT                 = 0xC0;
private enum THREE_BYTE_MASK                 = 0xF0;
private enum FOUR_BYTE_MASK                  = 0xF8;
private enum FIVE_BYTE_MASK                  = 0xFC;
private enum SIX_BYTE_MASK                   = 0xFE;
private enum CONTINUING_MASK                 = 0xC0;

private fn _read_byte(str: string, ref index: size_t) u8
{
	if (index >= str.length) {
		throw new MalformedUTF8Exception("unexpected end of stream");
	}
	b: u8 = str[index];
	index = index + 1;
	return b;
}

private fn _read_char(str: string, ref index: size_t) dchar
{
	b: u8 = _read_byte(str, ref index);
	return cast(dchar)(b & cast(ubyte)~ONE_BYTE_MASK);
}

extern (C) fn vrt_reverse_decode_u8_d(str: string, ref index: size_t) dchar
{
	while ((str[index] & TWO_BYTE_RESULT) == ONE_BYTE_MASK) {
		if (index == 0) {
			throw new MalformedUTF8Exception("reverse_decode: malformed utf-8 string");
		}
		index--;
	}
	dummy: size_t = index;
	c := vrt_decode_u8_d(str, ref dummy);
	return c;
}

extern (C) fn vrt_decode_u8_d(str: string, ref index: size_t) dchar
{
	b1: u8 = _read_byte(str, ref index);
	if ((b1 & ONE_BYTE_MASK) == 0) {
		return b1;
	}

	c2: dchar = _read_char(str, ref index);
	if ((b1 & TWO_BYTE_MASK) == TWO_BYTE_RESULT) {
		c1: dchar = cast(dchar)((b1 & cast(ubyte)~TWO_BYTE_MASK));
		c1 = c1 << 6;
		return c1 | c2;
	}

	c3: dchar = _read_char(str, ref index);
	if ((b1 & THREE_BYTE_MASK) == TWO_BYTE_MASK) {
		c1: dchar = cast(dchar)((b1 & cast(ubyte)~THREE_BYTE_MASK));
		c1 = c1 << 12;
		c2 = c2 << 6;
		return c1 | c2 | c3;
	}

	c4: dchar = _read_char(str, ref index);
	if ((b1 & FOUR_BYTE_MASK) == THREE_BYTE_MASK) {
		c1: dchar = cast(dchar)((b1 & cast(ubyte)~FOUR_BYTE_MASK));
		c1 = c1 << 18;
		c2 = c2 << 12;
		c3 = c3 << 6;
		return c1 | c2 | c3 | c4;
	}

	c5: dchar = _read_char(str, ref index);
	if ((b1 & FIVE_BYTE_MASK) == FOUR_BYTE_MASK) {
		c1: dchar = cast(dchar)((b1 & cast(ubyte)~FIVE_BYTE_MASK));
		c1 = c1 << 24;
		c2 = c2 << 18;
		c3 = c3 << 12;
		c4 = c4 << 6;
		return c1 | c2 | c3 | c4 | c5;
	}

	c6: dchar = _read_char(str, ref index);
	if ((b1 & SIX_BYTE_MASK) == FIVE_BYTE_MASK) {
		c1: dchar = cast(dchar)((b1 & cast(ubyte)~SIX_BYTE_MASK));
		c1 = c1 << 30;
		c2 = c2 << 24;
		c3 = c3 << 18;
		c4 = c4 << 12;
		c5 = c5 << 6;
		return c1 | c2 | c3 | c4 | c5 | c6;
	}

	throw new MalformedUTF8Exception("utf-8 decode failure");
}

/// Return how many codepoints are in a given UTF-8 string.
extern (C) fn vrt_count_codepoints_u8(s: string) size_t
{
	i, length: size_t;
	while (i < s.length) {
		vrt_decode_u8_d(s, ref i);
		length++;
	}
	return length;
}

extern (C) fn vrt_validate_u8(s: string)
{
	i: size_t;
	while (i < s.length) {
		vrt_decode_u8_d(s, ref i);
	}
	return;
}

/// Encode c as UTF-8.
extern (C) fn vrt_encode_static_u8(ref buf: char[6], c: dchar) size_t
{
	cval := cast(u32) c;

	fn readU8(a: u32, b: u32) u8
	{
		_byte := cast(u8) (a | (cval & b));
		cval = cval >> 6;
		return _byte;
	}

	if (cval <= 0x7F) {
		buf[0] = cast(char) c;
		return 1;
	} else if (cval >= 0x80 && cval <= 0x7FF) {
		buf[1] = readU8(0x0080, 0x003F);
		buf[0] = readU8(0x00C0, 0x001F);
		return 2;
	} else if (cval >= 0x800 && cval <= 0xFFFF) {
		buf[2] = readU8(0x0080, 0x003F);
		buf[1] = readU8(0x0080, 0x003F);
		buf[0] = readU8(0x00E0, 0x000F);
		return 3;
	} else if (cval >= 0x10000 && cval <= 0x1FFFFF) {
		buf[3] = readU8(0x0080, 0x003F);
		buf[2] = readU8(0x0080, 0x003F);
		buf[1] = readU8(0x0080, 0x003F);
		buf[0] = readU8(0x00F0, 0x000E);
		return 4;
	} else if (cval >= 0x200000 && cval <= 0x3FFFFFF) {
		buf[4] = readU8(0x0080, 0x003F);
		buf[3] = readU8(0x0080, 0x003F);
		buf[2] = readU8(0x0080, 0x003F);
		buf[1] = readU8(0x0080, 0x003F);
		buf[0] = readU8(0x00F8, 0x0007);
		return 5;
	} else if (cval >= 0x4000000 && cval <= 0x7FFFFFFF) {
		buf[5] = readU8(0x0080, 0x003F);
		buf[4] = readU8(0x0080, 0x003F);
		buf[3] = readU8(0x0080, 0x003F);
		buf[2] = readU8(0x0080, 0x003F);
		buf[1] = readU8(0x0080, 0x003F);
		buf[0] = readU8(0x00FC, 0x0001);
		return 6;
	} else {
		throw new MalformedUTF8Exception("encode: unsupported codepoint range");
	}
}
