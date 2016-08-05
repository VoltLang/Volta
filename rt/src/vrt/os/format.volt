// Copyright © 2013-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.format;

import vrt.ext.stdc : snprintf;
import core.rt.format : Sink, SinkArg;


extern(C) fn vrt_format_u64(sink: Sink, i: u64)
{
	buf: char[32];
	index: size_t = buf.length;
	inLoop := true;

	do {
		remainder: u64 = i % 10;
		i = i / 10;
		buf[--index] = cast(char)('0' + remainder);
	} while (i != 0);

	sink(buf[index .. $]);
}

extern(C) fn vrt_format_i64(sink: Sink, i: i64)
{
	buf: char[32];
	index: size_t = buf.length;
	negative: bool = i < 0;
	if (negative) {
		i = i * -1;
	}

	do {
		remainder: i64 = i % 10;
		i = i / 10;
		buf[--index] = cast(char)('0' + remainder);
	} while (i != 0);

	if (negative) {
		buf[--index] = '-';
	}

	sink(buf[index .. $]);
}

global hexDigits: string = "0123456789ABCDEF";

extern(C) fn vrt_format_hex(sink: Sink, i: u64, padding: size_t)
{
	buf: char[16];
	index: size_t = buf.length;

	do {
		remainder := cast(size_t)(i & 0xFU);
		i = i >> 4;
		buf[--index] = hexDigits[remainder];
	} while (i != 0);

	padding = padding > buf.length ? 0 : buf.length - padding;

	while (padding < index) {
		buf[--index] = '0';
	}

	sink(buf[index .. $]);
}

version (!Metal):

extern(C) fn vrt_format_f32(sink: Sink, f: f32)
{
	buf: char[1024];
	retval := snprintf(buf.ptr, buf.length, "%f", f);

	if (retval > 0) {
		sink(buf[0 .. retval]);
	}
}

extern(C) fn vrt_format_f64(sink: Sink, f: f64)
{
	buf: char[1024];
	retval := snprintf(buf.ptr, buf.length, "%f", f);

	if (retval > 0) {
		sink(buf[0 .. retval]);
	}
}
