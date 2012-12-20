// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module object;

// This is all up in the air.
alias AllocDg = void delegate(uint size);

local AllocDg allocDg;

extern(C) AllocDg vrt_gc_get_alloc_dg();
