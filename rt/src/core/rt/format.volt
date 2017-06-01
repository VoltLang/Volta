// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.format;


/// The one true sink definition.
alias SinkArg = scope const(char)[];

/// The argument to the one true sink.
alias Sink = scope dg (SinkArg);

extern(C) fn vrt_format_u64(sink: Sink, i: u64);
extern(C) fn vrt_format_i64(sink: Sink, i: i64);
extern(C) fn vrt_format_f32(sink: Sink, i: f32, width: i32 = -1);
extern(C) fn vrt_format_f64(sink: Sink, i: f64, width: i32 = -1);
extern(C) fn vrt_format_hex(sink: Sink, i: u64, padding: size_t);
extern(C) fn vrt_format_readable_size(sink: Sink, size: u64);
