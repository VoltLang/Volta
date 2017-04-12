// Copyright © 2016-2017, Bernard Helyer.
// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.errors;

import core.rt.format : SinkArg, vrt_format_u64;
import core.rt.misc : vrt_panic;


fn panicFailedToAlloc(n: size_t)
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
	vrt_panic(args[]);
}
