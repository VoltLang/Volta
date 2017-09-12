// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.eh;

import core.rt.misc;
import core.exception;


extern(C):

/*!
 * Temporary shortcuts.
 */
alias vrt_eh_throw = core.rt.misc.vrt_eh_throw;
alias vrt_eh_throw_slice_error = core.rt.misc.vrt_eh_throw_slice_error;
alias vrt_eh_throw_assert_error = core.rt.misc.vrt_eh_throw_assert_error;
alias vrt_eh_throw_key_not_found_error = core.rt.misc.vrt_eh_throw_key_not_found_error;
alias vrt_eh_personality_v0 = core.rt.misc.vrt_eh_personality_v0;

/*!
 * Set a callback that happens just before a exception is thrown.
 *
 * The callback is per thread (for those platforms that support TLS).
 *
 * Do not throw from the callback, as it will explode.
 */
fn vrt_eh_set_callback(cb: fn(Throwable, string));
