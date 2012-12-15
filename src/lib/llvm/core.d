// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice and license below.

/**
 * This file imports the regular C api of LLVM but also extends it
 * with simple wrappers that works on native arrays instead of C
 * pointer plus length arrays as well as string wrappers.
 */
module lib.llvm.core;

import std.conv : to;
import std.string : toStringz;
public import lib.llvm.c.Core;


// Need to do this for all overloaded functions.
alias lib.llvm.c.Core.LLVMModuleCreateWithNameInContext LLVMModuleCreateWithNameInContext;
alias lib.llvm.c.Core.LLVMFunctionType LLVMFunctionType;
alias lib.llvm.c.Core.LLVMStructCreateNamed LLVMStructCreateNamed;
alias lib.llvm.c.Core.LLVMGetStructName LLVMGetStructNamez;
alias lib.llvm.c.Core.LLVMStructSetBody LLVMStructSetBody;
alias lib.llvm.c.Core.LLVMConstNamedStruct LLVMConstNamedStruct;
alias lib.llvm.c.Core.LLVMConstStringInContext LLVMConstStringInContext;
alias lib.llvm.c.Core.LLVMConstInBoundsGEP LLVMConstInBoundsGEP;
alias lib.llvm.c.Core.LLVMAddFunction LLVMAddFunction;
alias lib.llvm.c.Core.LLVMBuildCall LLVMBuildCall;
alias lib.llvm.c.Core.LLVMBuildAlloca LLVMBuildAlloca;
alias lib.llvm.c.Core.LLVMAddGlobal LLVMAddGlobal;
alias lib.llvm.c.Core.LLVMBuildGEP LLVMBuildGEP;
alias lib.llvm.c.Core.LLVMBuildInBoundsGEP LLVMBuildInBoundsGEP;

LLVMModuleRef LLVMModuleCreateWithNameInContext(string name, LLVMContextRef c)
{
	char[1024] stack;
	auto ptr = nullTerminate(stack, name);
	return lib.llvm.c.Core.LLVMModuleCreateWithNameInContext(ptr, c);
}

LLVMTypeRef LLVMFunctionType(LLVMTypeRef ret, LLVMTypeRef[] args, bool vararg)
{
	return lib.llvm.c.Core.LLVMFunctionType(
		ret, args.ptr, cast(uint)args.length, vararg);
}

LLVMTypeRef LLVMStructCreateNamed(LLVMContextRef c, string name)
{
	char[1024] stack;
	auto ptr = nullTerminate(stack, name);
	return lib.llvm.c.Core.LLVMStructCreateNamed(c, ptr);
}

LLVMValueRef LLVMConstNamedStruct(LLVMTypeRef structType,
                                  LLVMValueRef[] constantVals)
{
	return lib.llvm.c.Core.LLVMConstNamedStruct(
		structType, constantVals.ptr, cast(uint)constantVals.length);
}

string LLVMGetStructName(LLVMTypeRef t)
{
	return to!string(lib.llvm.c.Core.LLVMGetStructName(t));
}

void LLVMStructSetBody(LLVMTypeRef t, LLVMTypeRef[] types, LLVMBool packed)
{
	lib.llvm.c.Core.LLVMStructSetBody(t, types.ptr, cast(uint)types.length, packed);
}

LLVMValueRef LLVMConstStringInContext(LLVMContextRef c, const(char)[] str, bool nullTerminate)
{
	return lib.llvm.c.Core.LLVMConstStringInContext(
		c, str.ptr, cast(uint)str.length, nullTerminate);
}

LLVMValueRef LLVMConstInBoundsGEP(LLVMValueRef val, LLVMValueRef[] indices)
{
	return lib.llvm.c.Core.LLVMConstInBoundsGEP(
		val, indices.ptr, cast(uint)indices.length);
}

LLVMValueRef LLVMAddFunction(LLVMModuleRef mod, string name, LLVMTypeRef type)
{
	char[1024] stack;
	auto ptr = nullTerminate(stack, name);
	return lib.llvm.c.Core.LLVMAddFunction(mod, ptr, type);
}


LLVMValueRef LLVMBuildCall(LLVMBuilderRef b, LLVMValueRef func,
                           LLVMValueRef[] args)
{
	return lib.llvm.c.Core.LLVMBuildCall(
		b, func, args.ptr, cast(uint)args.length, "");
}

LLVMValueRef LLVMBuildAlloca(LLVMBuilderRef b, LLVMTypeRef type,
                             string name)
{
	char[1024] stack;
	auto ptr = nullTerminate(stack, name);
	return lib.llvm.c.Core.LLVMBuildAlloca(b, type, ptr);
}

LLVMValueRef LLVMAddGlobal(LLVMModuleRef mod, LLVMTypeRef type,
                           string name)
{
	char[1024] stack;
	auto ptr = nullTerminate(stack, name);
	return lib.llvm.c.Core.LLVMAddGlobal(mod, type, ptr);
}

LLVMValueRef LLVMBuildGEP(LLVMBuilderRef b, LLVMValueRef ptr,
                          LLVMValueRef[] i,
                          string name)
{
	char[1024] stack;
	auto namez = nullTerminate(stack, name);

	return LLVMBuildGEP(b, ptr, i.ptr, cast(uint)i.length, namez);
}

LLVMValueRef LLVMBuildInBoundsGEP(LLVMBuilderRef b, LLVMValueRef ptr,
	                              LLVMValueRef[] i,
                                  string name)
{
	char[1024] stack;
	auto namez = nullTerminate(stack, name);

	return LLVMBuildInBoundsGEP(b, ptr, i.ptr, cast(uint)i.length, namez);
}

/**
 * Small helper function that writes a string and null terminates
 * it to a given char array, usefull for using stack space to null
 * terminate strings.
 */
const(char)* nullTerminate(char[] stack, string str)
{
	if (str.length + 1 > stack.length)
		return toStringz(str);
	stack[0 .. str.length] = str;
	stack[str.length] = 0;
	return stack.ptr;
}


/*
 * License.
 */


string llvmLicense = `
==============================================================================
LLVM Release License
==============================================================================
University of Illinois/NCSA
Open Source License

Copyright (c) 2003-2010 University of Illinois at Urbana-Champaign.
All rights reserved.

Developed by:

    LLVM Team

    University of Illinois at Urbana-Champaign

    http://llvm.org

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal with
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimers.

    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimers in the
      documentation and/or other materials provided with the distribution.

    * Neither the names of the LLVM Team, University of Illinois at
      Urbana-Champaign, nor the names of its contributors may be used to
      endorse or promote products derived from this Software without specific
      prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE
SOFTWARE.
`;

import volt.license;

static this()
{
	licenseArray ~= llvmLicense;
}
