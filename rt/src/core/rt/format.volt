// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.format;


/// The one true sink definition.
alias SinkArg = scope const(char)[];

/// The argument to the one true sink.
alias Sink = scope void delegate(SinkArg);

extern(C) fn vrt_format_u64(sink: Sink, i: u64);
extern(C) fn vrt_format_i64(sink: Sink, i: i64);
extern(C) fn vrt_format_f32(sink: Sink, i: f32);
extern(C) fn vrt_format_f64(sink: Sink, i: f64);
extern(C) fn vrt_format_hex(sink: Sink, i: u64, padding: size_t);
