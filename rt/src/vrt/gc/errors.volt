// Copyright 2016-2024, Bernard Helyer.
// Copyright 2016-2024, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module vrt.gc.errors;

import core.rt.format : SinkArg, vrt_format_i64, vrt_format_u64;
import core.rt.misc : vrt_panic;

version (CRuntime_All) {
	import core.c.string : strerror, strlen;
}

// General purpose allocation failure message.
fn panicFailedToAlloc(n: size_t, loc: string = __LOCATION__)
{
	args: char[][1];
	msg: char[128];
	pos: size_t;

	fn sink(buf: SinkArg) {
		end := pos + buf.length;
		msg[pos .. end] = buf;
		pos += buf.length;
	}

	sink("Alloc of ");
	vrt_format_u64(sink, n);
	sink(" bytes failed.");

	args[0] = msg[0 .. pos];
	vrt_panic(args[], loc);
}

// Same as above, but with an errno value describing the failure.
fn panicFailedToAlloc(n: size_t, ret: int, loc: string = __LOCATION__)
{
	args: char[][1];
	msg: char[128];
	pos: size_t;

	fn sink(buf: SinkArg) {
		end := pos + buf.length;
		msg[pos .. end] = buf;
		pos += buf.length;
	}

	sink("Alloc of ");
	vrt_format_u64(sink, n);
	sink(" bytes failed with ");
	errnoToSink(sink, ret);
	sink(".");

	args[0] = msg[0 .. pos];
	vrt_panic(args[], loc);
}

// Specific error message for when mmap fails, where ret is errno.
fn panicMmapFailed(n: size_t, ret: int, loc: string = __LOCATION__)
{
	args: char[][1];
	msg: char[256];
	pos: size_t;

	fn sink(buf: SinkArg) {
		end := pos + buf.length;
		msg[pos .. end] = buf;
		pos += buf.length;
	}

	sink("gc mmap of ");
	vrt_format_u64(sink, n);
	sink(" bytes failed with ");
	errnoToSink(sink, ret);

	args[0] = msg[0 .. pos];
	vrt_panic(args[], loc);
}

private:

// Helper function to pass errno into a sink.
fn errnoToSink(sink: dg(SinkArg), ret: int)
{
	version (CRuntime_All) {
		str := strerror(ret);
		if (str !is null) {
			sink("'");
			sink(str[0 .. strlen(str)]);
			sink("' (");
			vrt_format_i64(sink, ret);
			sink(")");
		} else {
			vrt_format_i64(sink, ret);
		}
	} else {
		vrt_format_i64(sink, ret);
	}
}