// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.ext.unwind;


version (!Emscripten && !MSVC && !Metal):

extern(C):

// True for now
alias uintptr_t = size_t;

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
		ulong exception_class;
		_Unwind_Exception_Cleanup_Fn exception_cleanup;
		void* pad1;

		uintptr_t private_1;
		void* pad2;
		uintptr_t private_2;
		void* pad3;
	}
} else {
	struct _Unwind_Exception
	{
		ulong exception_class;
		_Unwind_Exception_Cleanup_Fn exception_cleanup;

		uintptr_t private_1;
		uintptr_t private_2;
	}
}

alias _Unwind_Exception_Cleanup_Fn = void function(_Unwind_Reason_Code, _Unwind_Exception*);

struct _Unwind_Context {}

int _Unwind_Resume(_Unwind_Exception*);
int _Unwind_RaiseException(_Unwind_Exception*);

const ubyte* _Unwind_GetLanguageSpecificData(_Unwind_Context* ctx);

size_t _Unwind_GetRegionStart(_Unwind_Context* ctx);
size_t _Unwind_GetTextRelBase(_Unwind_Context* ctx);
size_t _Unwind_GetDataRelBase(_Unwind_Context* ctx);

size_t _Unwind_GetGR(_Unwind_Context* ctx, int i);
uintptr_t _Unwind_GetIP(_Unwind_Context  *ctx);

void _Unwind_SetGR(_Unwind_Context* ctx, int i, size_t n);
void _Unwind_SetIP(_Unwind_Context* ctx, uintptr_t new_value);
