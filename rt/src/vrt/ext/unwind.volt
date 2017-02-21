// Copyright © 2013-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Written by hand from documentation.
module vrt.ext.unwind;


import vrt.ext.stdc: uintptr_t;

version (!MSVC && !Metal):

extern(C):

enum _Unwind_Reason_Code
{
	NO_REASON                = 0,
	FOREIGN_EXCEPTION_CAUGHT = 1,
	FATAL_PHASE2_ERROR       = 2,
	FATAL_PHASE1_ERROR       = 3,
	NORMAL_STOP              = 4,
	END_OF_STACK             = 5,
	HANDLER_FOUND            = 6,
	INSTALL_CONTEXT          = 7,
	CONTINUE_UNWIND          = 8
}

enum _Unwind_Action
{
	SEARCH_PHASE  = 1,
	CLEANUP_PHASE = 2,
	HANDLER_FRAME = 4,
	FORCE_UNWIND  = 8,
	END_OF_STACK  = 16
}

// XXX The IA-64 ABI says that this structure must be double-word aligned.
// We probably don't follow that.
version (Windows) {
	struct _Unwind_Exception
	{
		exception_class: u64;
		exception_cleanup: _Unwind_Exception_Cleanup_Fn;
		pad1: void*;

		private_1: uintptr_t;
		pad2: void*;
		private_2: uintptr_t;
		pad3: void*;
	}
} else {
	struct _Unwind_Exception
	{
		exception_class: u64;
		exception_cleanup: _Unwind_Exception_Cleanup_Fn;

		private_1: uintptr_t;
		private_2: uintptr_t;
	}
}

alias _Unwind_Exception_Cleanup_Fn = fn (_Unwind_Reason_Code, _Unwind_Exception*);

struct _Unwind_Context {}

fn _Unwind_Resume(_Unwind_Exception*) int;
fn _Unwind_RaiseException(_Unwind_Exception*) int;

const fn _Unwind_GetLanguageSpecificData(ctx: _Unwind_Context*) ubyte*;

fn _Unwind_GetRegionStart(ctx: _Unwind_Context*) size_t;
fn _Unwind_GetTextRelBase(ctx: _Unwind_Context*) size_t;
fn _Unwind_GetDataRelBase(ctx: _Unwind_Context*) size_t;

fn _Unwind_GetGR(ctx: _Unwind_Context*, i: i32) size_t;
fn _Unwind_GetIP(ctx: _Unwind_Context*) uintptr_t;

fn _Unwind_SetGR(ctx: _Unwind_Context*, i: i32, n: size_t);
fn _Unwind_SetIP(ctx: _Unwind_Context*, new_value: uintptr_t);
