// Copyright © 2013-2015, Bernard Helyer.
// See copyright notice in src/volt/licence.d (BOOST ver 1.0)
module vrt.vacuum.utf;


private enum ONE_BYTE_MASK                   = 0x80;
private enum TWO_BYTE_MASK                   = 0xE0;
private enum TWO_BYTE_RESULT                 = 0xC0;
private enum THREE_BYTE_MASK                 = 0xF0;
private enum FOUR_BYTE_MASK                  = 0xF8;
private enum FIVE_BYTE_MASK                  = 0xFC;
private enum SIX_BYTE_MASK                   = 0xFE;
private enum CONTINUING_MASK                 = 0xC0;

private ubyte _read_byte(string str, ref size_t index)
{
	if (index >= str.length) {
		throw new object.MalformedUTF8Exception("unexpected end of stream");
	}
	ubyte b = str[index];
	index = index + 1;
	return b;
}

private dchar _read_char(string str, ref size_t index)
{
	ubyte b = _read_byte(str, ref index);
	return cast(dchar)(b & cast(ubyte)~ONE_BYTE_MASK);
}

extern (C) dchar vrt_reverse_decode_u8_d(string str, ref size_t index)
{
	while ((str[index] & TWO_BYTE_RESULT) == ONE_BYTE_MASK) {
		if (index == 0) {
			throw new object.MalformedUTF8Exception("reverse_decode: malformed utf-8 string");
		}
		index--;
	}
	size_t dummy = index;
	auto c = vrt_decode_u8_d(str, ref dummy);
	return c;
}

extern (C) dchar vrt_decode_u8_d(string str, ref size_t index)
{
	ubyte b1 = _read_byte(str, ref index);
	if ((b1 & ONE_BYTE_MASK) == 0) {
		return b1;
	}

	dchar c2 = _read_char(str, ref index);
	if ((b1 & TWO_BYTE_MASK) == TWO_BYTE_RESULT) {
		dchar c1 = cast(dchar)((b1 & cast(ubyte)~TWO_BYTE_MASK));
		c1 = c1 << 6;
		return c1 | c2;
	}

	dchar c3 = _read_char(str, ref index);
	if ((b1 & THREE_BYTE_MASK) == TWO_BYTE_MASK) {
		dchar c1 = cast(dchar)((b1 & cast(ubyte)~THREE_BYTE_MASK));
		c1 = c1 << 12;
		c2 = c2 << 6;
		return c1 | c2 | c3;
	}

	dchar c4 = _read_char(str, ref index);
	if ((b1 & FOUR_BYTE_MASK) == THREE_BYTE_MASK) {
		dchar c1 = cast(dchar)((b1 & cast(ubyte)~FOUR_BYTE_MASK));
		c1 = c1 << 18;
		c2 = c2 << 12;
		c3 = c3 << 6;
		return c1 | c2 | c3 | c4;
	}

	dchar c5 = _read_char(str, ref index);
	if ((b1 & FIVE_BYTE_MASK) == FOUR_BYTE_MASK) {
		dchar c1 = cast(dchar)((b1 & cast(ubyte)~FIVE_BYTE_MASK));
		c1 = c1 << 24;
		c2 = c2 << 18;
		c3 = c3 << 12;
		c4 = c4 << 6;
		return c1 | c2 | c3 | c4 | c5;
	}

	dchar c6 = _read_char(str, ref index);
	if ((b1 & SIX_BYTE_MASK) == FIVE_BYTE_MASK) {
		dchar c1 = cast(dchar)((b1 & cast(ubyte)~SIX_BYTE_MASK));
		c1 = c1 << 30;
		c2 = c2 << 24;
		c3 = c3 << 18;
		c4 = c4 << 12;
		c5 = c5 << 6;
		return c1 | c2 | c3 | c4 | c5 | c6;
	}

	throw new object.MalformedUTF8Exception("utf-8 decode failure");
}

/// Return how many codepoints are in a given UTF-8 string.
extern (C) size_t vrt_count_codepoints_u8(string s)
{
	size_t i, length;
	while (i < s.length) {
		vrt_decode_u8_d(s, ref i);
		length++;
	}
	return length;
}

extern (C) void vrt_validate_u8(string s)
{
	size_t i;
	while (i < s.length) {
		vrt_decode_u8_d(s, ref i);
	}
	return;
}

/// Encode c as UTF-8.
extern (C) string vrt_encode_d_u8(dchar c)
{
	char[] buf = new char[](6);
	auto cval = cast(uint) c;

	ubyte _read_byte(uint a, uint b)
	{
		ubyte _byte = cast(ubyte) (a | (cval & b));
		cval = cval >> 6;
		return _byte;
	}

	if (cval <= 0x7F) {
		buf[0] = cast(char) c;
		return cast(string)new buf[0 .. 1];
	} else if (cval >= 0x80 && cval <= 0x7FF) {
		buf[1] = _read_byte(0x0080, 0x003F);
		buf[0] = _read_byte(0x00C0, 0x001F);
		return cast(string)new buf[0 .. 2];
	} else if (cval >= 0x800 && cval <= 0xFFFF) {
		buf[2] = _read_byte(0x0080, 0x003F);
		buf[1] = _read_byte(0x0080, 0x003F);
		buf[0] = _read_byte(0x00E0, 0x000F);
		return cast(string)new buf[0 .. 3];
	} else if (cval >= 0x10000 && cval <= 0x1FFFFF) {
		buf[3] = _read_byte(0x0080, 0x003F);
		buf[2] = _read_byte(0x0080, 0x003F);
		buf[1] = _read_byte(0x0080, 0x003F);
		buf[0] = _read_byte(0x00F0, 0x000E);
		return cast(string)new buf[0 .. 4];
	} else if (cval >= 0x200000 && cval <= 0x3FFFFFF) {
		buf[4] = _read_byte(0x0080, 0x003F);
		buf[3] = _read_byte(0x0080, 0x003F);
		buf[2] = _read_byte(0x0080, 0x003F);
		buf[1] = _read_byte(0x0080, 0x003F);
		buf[0] = _read_byte(0x00F8, 0x0007);
		return cast(string)new buf[0 .. 5];
	} else if (cval >= 0x4000000 && cval <= 0x7FFFFFFF) {
		buf[5] = _read_byte(0x0080, 0x003F);
		buf[4] = _read_byte(0x0080, 0x003F);
		buf[3] = _read_byte(0x0080, 0x003F);
		buf[2] = _read_byte(0x0080, 0x003F);
		buf[1] = _read_byte(0x0080, 0x003F);
		buf[0] = _read_byte(0x00FC, 0x0001);
		return cast(string)new buf[0 .. 6];
	} else {
		throw new object.MalformedUTF8Exception("encode: unsupported codepoint range");
	}
}

