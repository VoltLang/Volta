// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.varargs;

fn __volt_va_start(vl: void**, _args: void*);
fn __volt_va_end(vl: void**);

extern (C):

@mangledName("llvm.va_start") fn __llvm_volt_va_start(void*);
@mangledName("llvm.va_end") fn __llvm_volt_va_end(void*);
