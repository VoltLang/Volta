// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.compiler.varargs;

public import core.compiler.llvm : __llvm_volt_va_start, __llvm_volt_va_end;


void __volt_va_start(void** vl, void* _args);
void __volt_va_end(void** vl);
