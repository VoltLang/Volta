// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.eh;


version (!Emscripten && !MSVC && !Metal):

import vrt.ext.unwind;
import vrt.ext.dwarf;
import vrt.ext.stdc : exit;


/*
 * Register mappings for exception and exception type selector.
 */
version (X86) {
	enum vrt_eh_return_0 = 0;
	enum vrt_eh_return_1 = 2;
} else version (X86_64) {
	enum vrt_eh_return_0 = 0;
	enum vrt_eh_return_1 = 1;
} else {
	static assert("arch not supported");
}

/**
 * Our exception struct, we put the exception after,
 * that seems to work, everybody else puts it before.
 */
struct vrt_eh_exception
{
	_Unwind_Exception e;
	object.Throwable t;
}

/**
 * Exception class, used to identify for other handlers.
 */
global auto VRT_EH_NAME = "VOLT___\0";

/**
 * Mandated by the ABI, not needed for Volt.
 */
extern(C) void vrt_eh_delete(
	_Unwind_Reason_Code reason,
	_Unwind_Exception* exceptionObject)
{
}

/**
 * Throws a exception.
 */
extern(C) void vrt_eh_throw(object.Throwable t, string file, size_t line)
{
	auto e = new vrt_eh_exception;

	t.throwFile = file;
	t.throwLine = line;

	e.e.exception_class = *cast(ulong*)VRT_EH_NAME.ptr;
	e.e.exception_cleanup = vrt_eh_delete;
	e.t = t;

	auto f = _Unwind_RaiseException(&e.e);
	char[][1] msgs;
	msgs[0] = "FAILED TO RAISE EXCEPTION";
	object.vrt_panic(msgs);
}

extern(C) void vrt_eh_throw_slice_error(string file, size_t line)
{
	vrt_eh_throw(new object.Error("invalid array cast"), file, line);
}

/**
 * Big do everything function.
 */
extern(C) _Unwind_Reason_Code vrt_eh_personality_v0(
	int ver,
	_Unwind_Action actions,
	ulong exceptionClass,
	_Unwind_Exception* exceptionObject,
	_Unwind_Context* ctx)
{
	// Get the current instruction pointer and offset it before next
	// instruction in the current frame which threw the exception.
	uintptr_t pc = _Unwind_GetIP(ctx) - 1;

	ubyte* data = _Unwind_GetLanguageSpecificData(ctx);
	if (data is null) {
		char[][1] msgs;
		msgs[0] = "non region data";
		object.vrt_panic(msgs);
		return _Unwind_Reason_Code.FATAL_PHASE1_ERROR;
	}

	// The region start is the same as the function start.
	// And all of the values in the callsite table are relative to it.
	uintptr_t funcStart = _Unwind_GetRegionStart(ctx);
	uintptr_t pcOffset = pc - funcStart;

	// Setup the dwarf context so we can read values.
	DW_Context dwCtx;
	version(!OSX) {
		dwCtx.textrel = cast(void*)_Unwind_GetTextRelBase(ctx);
		dwCtx.datarel = cast(void*)_Unwind_GetDataRelBase(ctx);
		dwCtx.funcrel = cast(void*)funcStart;
	}

	// Get lpStartBase, landing pad offsets are relative to it.
	uintptr_t lpStartBase;
	ubyte lpStartEncoding;

	lpStartEncoding = dw_read_ubyte(&data);
	if (lpStartEncoding == DW_EH_PE_omit) {
		lpStartBase = funcStart;
	} else {
		char[][1] msgs;
		msgs[0] = "unhandled lpStartEncoding";
		object.vrt_panic(msgs);
		return _Unwind_Reason_Code.FATAL_PHASE1_ERROR;
	}

	// Get the ttype offsets aka TypeInfo lists.
	// This can be null for empty lists.
	ubyte* typeInfo;
	ubyte typeInfoEncoding = dw_read_ubyte(&data);
	size_t typeInfoEncodingSize;

	if (typeInfoEncoding != DW_EH_PE_omit) {
		typeInfoEncodingSize = dw_encoded_size(typeInfoEncoding);
		// Calculate type info locations in emitted dwarf code which
		// were flagged by type info arguments to llvm.eh.selector
		// intrinsic.
		auto offset = dw_read_uleb128(&data);
		typeInfo = data + offset;
	}

	// Extract the Throwable object.
	object.Throwable throwable;
	if (exceptionObject.exception_class == *cast(ulong*)VRT_EH_NAME.ptr) {
		auto eh = cast(vrt_eh_exception*)exceptionObject;
		throwable = eh.t;
	} else {
		// Do no type checking if this is an foreign exception.
		typeInfo = null;
	}

	// Setup the call site table.
	ubyte callSiteEncoding = dw_read_ubyte(&data);
	uintptr_t callSiteTableLength;

	if (callSiteEncoding != DW_EH_PE_omit) {
		callSiteTableLength = dw_read_uleb128(&data);
	} else {
		char[][1] msgs;
		msgs[0] = "unhandled callingSiteEncoding";
		object.vrt_panic(msgs);
		return _Unwind_Reason_Code.FATAL_PHASE1_ERROR;
	}

	ubyte* callSiteTableStart = data;
	ubyte* callSiteTableEnd = data + callSiteTableLength;
	ubyte* actionTableStart = callSiteTableEnd;
	ubyte* callSitePtr = callSiteTableStart;

	// Walk the callsite table and find the callsite which the
	// pc is in currently, then look at which actions should be
	// performed by looking in the action table.
	while (cast(size_t)callSitePtr < cast(size_t)callSiteTableEnd) {

		auto rangeStart = dw_read_encoded(&callSitePtr, callSiteEncoding);
		auto rangeEnd = dw_read_encoded(&callSitePtr, callSiteEncoding) + rangeStart;
		auto landingPad = dw_read_encoded(&callSitePtr, callSiteEncoding);

		auto actionEntry = dw_read_uleb128(&callSitePtr);

		if (rangeStart <= pcOffset && pcOffset < rangeEnd) {

			// Calculate where we should set the pc if we want to use the landing pad.
			uintptr_t ip = lpStartBase + landingPad;

			if (landingPad == 0) {
				// They want us to escape the function,
				// happens with the resume intrinsic.
				return _Unwind_Reason_Code.CONTINUE_UNWIND;
			} else if (actionEntry == 0) {
				// No action specified, either this is a
				// forign exception being caught or a cleanup landing pad.
				return vrt_eh_install_finally(ip, actions, exceptionObject, ctx);
			} else {
				// Get the pointer into the ActionTable,
				// This needs to be subtracted by 1 because 0 (the beginning
				// of the table) is used to signal cleanup.
				auto actionPointer = actionTableStart + actionEntry - 1;

				// We start at 1 because 0 is cleanup.
				while (true) {
					auto typeOffset = dw_read_sleb128(&actionPointer);
					auto tmpPointer = actionPointer;
					auto actionOffset = dw_read_sleb128(&tmpPointer);

					if (typeOffset == 0) {
						return vrt_eh_install_finally(ip, actions, exceptionObject, ctx);
					}

					// If this is a forign exception or no type table found.
					if (typeInfo !is null) {
						auto ptr = typeInfo - (typeOffset * typeInfoEncodingSize);
						auto ti = cast(object.TypeInfo)dw_read_encoded(&ptr, typeInfoEncoding);
						auto casted = object.vrt_handle_cast(cast(void*)throwable, ti);
						if (casted !is null) {
							return vrt_eh_install_action(ip, actions, typeOffset, throwable, ctx);
						}
					}

					// No more actions, we are done now.
					if (actionOffset == 0) {
						return _Unwind_Reason_Code.CONTINUE_UNWIND;
					}
					actionPointer += cast(size_t)actionOffset;
				}

				char[][1] msgs;
				msgs[0] = "unhandled case";
				object.vrt_panic(msgs);
				return _Unwind_Reason_Code.FATAL_PHASE1_ERROR;
			}
		}
	}

	return _Unwind_Reason_Code.CONTINUE_UNWIND;
}

_Unwind_Reason_Code vrt_eh_install_action(
	uintptr_t ip,
	_Unwind_Action actions,
	uintptr_t switchVal,
	object.Throwable t,
	_Unwind_Context* ctx)
{
	// A finally doesn't count as a handler, so we should continue.
	if (actions & _Unwind_Action.SEARCH_PHASE) {
		return _Unwind_Reason_Code.HANDLER_FOUND;
	}

	_Unwind_SetGR(ctx, vrt_eh_return_0, cast(uintptr_t)t);
	_Unwind_SetGR(ctx, vrt_eh_return_1, switchVal);
	_Unwind_SetIP(ctx, ip);

	return _Unwind_Reason_Code.INSTALL_CONTEXT;
}

_Unwind_Reason_Code vrt_eh_install_finally(
	uintptr_t ip,
	_Unwind_Action actions,
	_Unwind_Exception* exceptionObject,
	_Unwind_Context* ctx)
{
	// A finally doesn't count as a handler, so we should continue.
	if (actions & _Unwind_Action.SEARCH_PHASE) {
		return _Unwind_Reason_Code.CONTINUE_UNWIND;
	}

	_Unwind_SetGR(ctx, vrt_eh_return_0, cast(uintptr_t)exceptionObject);
	_Unwind_SetGR(ctx, vrt_eh_return_1, 0);
	_Unwind_SetIP(ctx, ip);

	return _Unwind_Reason_Code.INSTALL_CONTEXT;
}
