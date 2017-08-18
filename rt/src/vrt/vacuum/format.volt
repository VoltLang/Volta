// Copyright © 2013-2017, Bernard Helyer.
// Copyright © 2013-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.vacuum.format;

import core.rt.format : Sink;

import vrt.vacuum.defines;


extern(C):

/*!
 * Turns a size into a human readable output.
 */
fn vrt_format_readable_size(sink: Sink, size: u64)
{
	if (size == 0) {
		return sink("0B");
	}

	if (size % _1GB == 0) {
		vrt_format_u64(sink, size / _1GB);
		return sink("GB");
	}

	if (size % _1MB == 0 && size < _1GB) {
		vrt_format_u64(sink, size / _1MB);
		return sink("MB");
	}

	if (size % _1KB == 0 && size < _1MB) {
		vrt_format_u64(sink, size / _1KB);
		return sink("KB");
	}

	orig := size;
	ret: string;
	if (size > _1GB) {
		v := size / _1GB;
		size -= v * _1GB;
		vrt_format_u64(sink, v);
		sink("GB ");
	}

	if (size > _1MB) {
		v := size / _1MB;
		size -= v * _1MB;
		vrt_format_u64(sink, v);
		sink("MB ");
	}

	if (size > _1KB) {
		v := size / _1KB;
		size -= v * _1KB;
		vrt_format_u64(sink, v);
		sink("KB ");
	}

	if (size != orig) {
		if (size) {
			vrt_format_u64(sink, size);
			sink("B (");
		} else {
			sink("(");
		}
		vrt_format_u64(sink, orig);
		return sink(")");
	} else {
		vrt_format_u64(sink, size);
		return sink("B");
	}
}

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
	if (i == i64.min) {
		/* Because we do the calculation by flipping
		 * negative values positive, this overflows.
		 * Hence, special case.
		 */
		sink("-9223372036854775808");
		return;
	}

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

extern(C) fn vrt_format_f32(sink: Sink, f: f32, width: i32)
{
	vrt_format_f64(sink, cast(f64)f, width);
}

extern(C) fn vrt_format_f64(sink: Sink, f: f64, width: i32)
{
	fmt_fp(sink, f, 0, width, 0);
}

enum DBL_MANT_DIG = 53;
enum DBL_MAX_EXP = 1024;
enum DBL_EPSILON = 2.22045e-16L;
enum INT_MAX = 0x7fffffff;
enum ALT_FORM = 8;  // !! 1U - '#' << ' '
enum LONG_MAX = 0x7fffffffffffffffL;

private fn fpbits(v: f64) u64
{
	return *cast(u64*)&v;
}

private fn signbit(v: f64) bool
{
	u := fpbits(v);
	return (u >> 63) != 0;
}

private fn isfinite(v: f64) bool
{
	u := fpbits(v);
	return (u & (cast(u64)-1)>>1) < (cast(u64)0x7FF)<<52;
}

private fn min(a: i32, b: i32) i32
{
	return a < b ? a : b;
}

private fn max(a: i32, b: i32) i32
{
	return a > b ? a : b;
}

private union dshape
{
	d: f64;
	i: u64;
};

private fn frexp(x: f64, e: i32*) f64
{
	y: dshape;
	y.d = x;
	ee: i32 = cast(i32)(y.i >> 52 & 0x7ff);

	if (!ee) {
		if (x) {
			x = frexp(x * 18446744073709551616.0, e);
			*e -= 64;
		} else *e = 0;
		return x;
	} else if (ee == 0x7ff) {
		return x;
	}

	*e = ee - 0x3fe;
	y.i &= 0x800fffffffffffffUL;
	y.i |= 0x3fe0000000000000UL;
	return y.d;
}

private fn fmt_u(x: u64, s: char*) char*
{
	y: u64;
	for (   ; x>2UL*LONG_MAX+1; x/=10) *--s = cast(char)('0' + x%10);
	for (y=x;           y; y/=10) *--s = cast(char)('0' + y%10);
	return s;
}

private fn fmt_fp(sink: Sink, f: f64, w: i32, p: i32, fl: i32)
{
	// 1835 == (LDBL_MANT_DIG+28)/29+1+(LDBL_MAX_EXP+LDBL_MANT_DIG+28+8)/9
	// TODO: Use that expression directly in big's declaration, once we support that.
	big: u32[1835];
	a, d, r, z: u32*;
	e2, e, i, j, l: i32;
	// 25 == (9+LDBL_MANT_DIG/4)
	// TODO: Use that expression directly in buf's declaration, once we support that.
	buf: char[25];
	s: char*;
	prefix: const(char)* = "-0X+0X 0X-0x+0x 0x".ptr;
	pl: i32;
	// 12 == 3 * typeid(i32).size
	// TODO: Use that expression in ebuf0 and ebuf, once we support that.
	ebuf0: char[12];
	ebuf: char* = &ebuf0[12];
	estr: char*;

	pl = 1;
	if (signbit(f)) {
		f = -f;
	} else {
		prefix++;
		pl = 0;
	}

	if (!isfinite(f)) {
		if (f != f) {
			sink("nan");
		} else {
			sink("inf");
		}
	}

	f = frexp(f, &e2) * 2;
	if (f) {
		e2--;
	}

	if (p < 0) {
		p = 6;
	}

	if (f) {
		f *= 268435456.0;  // This was 0x1p28, a literal format we don't support.
		e2 -= 28;
	}

	if (e2 < 0) {
		a = r = z = &big[0];
	} else {
		a = r = z = big.ptr + typeid(big[0]).size - DBL_MANT_DIG - 1;
	}

	do {
		*z = cast(u32)f;  // ?? f64 cast to u32
		f = 1000000000 * (f - *z++);
	} while (f);

	while (e2 > 0) {
		carry: u32 = 0;
		sh: i32 = min(29, -e2);
		for (d = z - 1; cast(size_t)d >= cast(size_t)a; --d) {
			x: u64 = (cast(u64)*d << cast(u32)sh) + carry;
			*d = cast(u32)(x % 1000000000);
			carry = cast(u32)(x / 1000000000);
		}
		if (carry) {
			*--a = carry;
		}
		while (cast(size_t)z > cast(size_t)a && !z[-1]) {
			z--;
		}
		e2 -= sh;
	}

	while (e2 < 0) {
		carry: u32 = 0;
		b: u32*;
		sh: i32 = min(9, -e2);
		need: i32 = 1 + (p + DBL_MANT_DIG / 3 + 8) / 9;
		for (d = a; cast(size_t)d < cast(size_t)z; ++d) {
			rm: u32 = *d & (1 << cast(u32)sh) - 1;
			*d = (*d >> cast(u32)sh) + carry;
			carry = (1000000000 >> cast(u32)sh) * rm;
		}
		if (!*a) {
			a++;
		}
		if (carry) {
			*z++ = carry;
		}
		b = r;
		if (cast(size_t)z - cast(size_t)b > cast(size_t)need) {
			z = b+need;
		}
		e2 += sh;
	}

	if (cast(size_t)a < cast(size_t)z) {
		for (i = 10, e = 9 * cast(i32)(cast(size_t)r - cast(size_t)a); *a >= cast(u32)i; i *= 10, ++e) {
		}
	} else {
		e = 0;
	}

	// Perform rounding: j is precision after the radix (possible neg).
	j = p;
	if (j < 9 * cast(i32)(cast(size_t)z - cast(size_t)r - 1)) {
		x: u32;
		// Avoid dividing negative numbers.
		d = r + 1 + ((j + 9 * DBL_MAX_EXP) / 9 - DBL_MAX_EXP);
		j += 9 * DBL_MAX_EXP;
		j %= 9;
		for (i = 10, j++; j < 9; i *= 10, j++) {
		}
		x = *d % cast(u32)i;
		// Are there any significant digits past j?
		if (x || cast(size_t)d + 1 != cast(size_t)z) {
			round: f64 = 2 / DBL_EPSILON;
			small: f64;
			if ((*d/cast(u32)i & 1) || (i == 1000000000 && cast(size_t)d > cast(size_t)a && (d[-1] & 1))) {
				round += 2;
			}
			if (x < cast(u32)i / 2) {
				small = 0.0;  // !! 0x0.8p0 => 0.5
			} else if (x == cast(u32)i / 2 && cast(size_t)d + 1 == cast(size_t)z) {
				small = 1.0;  // !! 0x1.0p0 => 1.0
			} else {
				small = 1.5;  // !! 0x1.8p0 => 1.5
			}
			if (pl && *prefix == '-') {
				round *= 1;
				small *= -1.0;
			}
			*d -= x;
			// Decide whether to round by probing round+small.
			if (round + small != round) {
				*d = *d + cast(u32)i;
				while (*d > 999999999) {
					*d-- = 0;
					if (cast(size_t)d < cast(size_t)a) {
						*--a = 0;
					}
					(*d)++;
				}
				for (i = 10, e = 9 * cast(i32)(cast(size_t)r - cast(size_t)a); *a >= cast(u32)i; i *= 10, e++) {
				}
			}
		}
		if (cast(size_t)z > cast(size_t)d + 1) {
			z = d + 1;
		}
	}
	for (; cast(size_t)z > cast(size_t)a && !z[-1]; --z) {
	}

	assert(!(p > INT_MAX-1-(p || (fl&ALT_FORM))));
	l = 1 + p + (p || (fl&ALT_FORM));
	assert(!(e > INT_MAX-l));
	if (e > 0) {
		l+=e;
	}

	assert(!(l > INT_MAX - pl));

	sink(prefix[0 .. pl]);

	if (cast(size_t)a > cast(size_t)r) {
		a = r;
	}
	for (d=a; cast(size_t)d <= cast(size_t)r; d++) {
		ss: char* = fmt_u(*d, buf.ptr+9);
		if (d !is a) while (cast(size_t)ss > cast(size_t)buf.ptr) *--ss='0';
		else if (ss is buf.ptr+9) *--ss='0';
		sink(ss[0 .. cast(size_t)buf.ptr + 9 - cast(size_t)ss]);
	}
	if (p != 0) {
		sink(".");
	}
	for (; cast(size_t)d < cast(size_t)z && p>0; d++, p-=9) {
		ss: char* = fmt_u(*d, buf.ptr+9);
		while (cast(size_t)ss > cast(size_t)buf.ptr) *--ss='0';
		sink(ss[0 .. min(9, p)]);
	}
	foreach (ii; 0 .. p) {
		sink("0");
	}
}
