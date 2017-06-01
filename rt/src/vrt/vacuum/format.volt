// Copyright © 2013-2017, Bernard Helyer.
// Copyright © 2013-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.vacuum.format;

import core.rt.format : Sink, vrt_format_u64;

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

	if (size % _1MB == 0) {
		vrt_format_u64(sink, size / _1MB);
		return sink("MB");
	}

	if (size % _1KB == 0) {
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
