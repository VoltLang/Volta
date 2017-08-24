// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.format;


/// The one true sink definition.
alias SinkArg = scope const(char)[];

/// The argument to the one true sink.
alias Sink = scope dg (SinkArg);

/*!
 * Format a given `u64` as a string, and pass it to `sink`.
 */
extern(C) fn vrt_format_u64(sink: Sink, i: u64);
/*!
 * Format a given `i64` as a string, and pass it to `sink`.
 */
extern(C) fn vrt_format_i64(sink: Sink, i: i64);
/*!
 * Format a given `f32` as a string, and pass it to `sink`.
 *
 * The `width` determines the rounding point. `-1` leaves it as the
 * implementation default.
 */
extern(C) fn vrt_format_f32(sink: Sink, i: f32, width: i32 = -1);
/*!
 * Format a given `f64` as a string, and pass it to `sink`.
 *
 * The `width` determines the rounding point. `-1` leaves it as the
 * implementation default.
 */
extern(C) fn vrt_format_f64(sink: Sink, i: f64, width: i32 = -1);
/*!
 * Format a given integer as a hex string, and pass it to `sink`.
 *
 * The hex letters will be uppercase, it will not be preceded with
 * `0x`, and `padding` specifies the minimum length of the string --
 * if the result is less, it will be filled in with `0` characters.
 */
extern(C) fn vrt_format_hex(sink: Sink, i: u64, padding: size_t);
/*!
 * Format a given `u64` and pass it to `sink`.
 */
extern(C) fn vrt_format_readable_size(sink: Sink, size: u64);
/*!
 * Format a given `dchar` as a string (surrounded with `'`) and
 * pass it to `sink`.
 */
extern(C) fn vrt_format_dchar(sink: Sink, c: dchar);

/*!
 * These are the sink store that the compiler uses for composable strings.
 *
 * The returned delegate is only valid as long as the storage of the SinkStore
 * is valid.
 * @{
 */
alias SinkStore = SinkStore1024;
alias vrt_sink_init = vrt_sink_init_1024;
//! @}

/*!
 * Default implementation of SinkStore used by the compiler.
 * @{
 */
alias SinkStore1024 = void[1024];
extern(C) fn vrt_sink_init_1024(ref sink: SinkStore1024) Sink;
extern(C) fn vrt_sink_getstr_1024(ref sink: SinkStore1024) string;
//! @}
