// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.eh_stub;

import core.exception: Throwable, Error, AssertError, KeyNotFoundException;
import core.rt.misc: vrt_panic;


version (MSVC || Metal):

extern(C) fn vrt_eh_throw(t: Throwable, location: string)
{
	msgs: const(char)[][2];
	msgs[0] = "###EXCEPTION###\n";
	msgs[1] = cast(char[])t.msg;
	vrt_panic(cast(char[][])msgs, location);
}

extern(C) fn vrt_eh_throw_slice_error(length: size_t, targetSize: size_t, location: string)
{
	if ((length % targetSize) != 0) {
		vrt_eh_throw(new Error("invalid array cast"), location);
	}
}

extern(C) fn vrt_eh_throw_assert_error(location: string, msg: string)
{
	vrt_eh_throw(new AssertError(msg), location);
}

extern(C) fn vrt_eh_throw_key_not_found_error(location: string)
{
	vrt_eh_throw(new KeyNotFoundException("key does not exist"), location);
}

extern(C) fn vrt_eh_personality_v0()
{
}

extern(C) fn _Unwind_Resume()
{
}
