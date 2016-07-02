// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.utf;


extern(C):

dchar vrt_decode_u8_d(string str, ref size_t index);
dchar vrt_reverse_decode_u8_d(string str, ref size_t index);
