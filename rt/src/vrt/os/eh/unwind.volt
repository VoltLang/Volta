// Copyright 2013-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
//! Exception handling using libunwind and DWARF.
module vrt.os.eh.unwind;

version ((Linux || OSX || MinGW) && !ARMHF):

import core.rt.misc: vrt_panic, vrt_handle_cast;
import core.typeinfo: TypeInfo;
import core.exception: Throwable, Error, AssertError, KeyNotFoundException;

import vrt.ext.unwind;
import vrt.ext.dwarf;
import vrt.ext.stdc: exit, uintptr_t;
import vrt.os.eh.common;


/*
 * Register mappings for exception and exception type selector.
 */
version (X86) {

	enum vrt_eh_return_0 = 0;
	enum vrt_eh_return_1 = 2;

} else version (X86_64) {

	enum vrt_eh_return_0 = 0;
	enum vrt_eh_return_1 = 1;

} else version (ARMHF) {

	enum vrt_eh_return_0 = 0;
	enum vrt_eh_return_1 = 1;

} else version (AArch64) {

	enum vrt_eh_return_0 = 0;
	enum vrt_eh_return_1 = 1;

} else {

	static assert(false, "arch not supported");

}

/*!
 * Our exception struct, we put the exception after,
 * that seems to work, everybody else puts it before.
 */
struct vrt_eh_exception
{
	e: _Unwind_Exception;
	t: Throwable;
}

/*!
 * Per thread callback for applications getting exceptions.
 */
local lCallback : fn(Throwable, location: string);

extern(C) fn vrt_eh_set_callback(cb: fn(Throwable, location: string))
{
	lCallback = cb;
}

/*!
 * Throws an exception.
 */
extern(C) fn vrt_eh_throw(t: Throwable, location: string)
{
	if (lCallback !is null) {
		lCallback(t, location);
	}

	e := new vrt_eh_exception;

	t.throwLocation = location;

	e.e.exception_class = *cast(u64*)VRT_EH_NAME.ptr;
	e.e.exception_cleanup = vrt_eh_delete;
	e.t = t;

	f := _Unwind_RaiseException(&e.e);
	msgs: char[][3];
	msgs[0] = cast(char[])"FAILED TO RAISE EXCEPTION";
	msgs[2] = cast(char[])t.throwLocation;
	msgs[1] = cast(char[])t.msg;
	vrt_panic(cast(char[][])msgs);
}

extern(C) fn vrt_eh_rethrow(t: Throwable)
{
	// No callback, don't touch throwLocation.

	e := new vrt_eh_exception;

	e.e.exception_class = *cast(u64*)VRT_EH_NAME.ptr;
	e.e.exception_cleanup = vrt_eh_delete;
	e.t = t;

	f := _Unwind_RaiseException(&e.e);
	msgs: char[][4];
	msgs[0] = cast(char[])"FAILED TO RAISE EXCEPTION";
	msgs[1] = cast(char[])t.msg;
	msgs[2] = cast(char[])t.location;
	msgs[3] = cast(char[])t.throwLocation;
	vrt_panic(cast(char[][])msgs);
}

extern(C) fn vrt_eh_throw_assert_error(location: string, msg: string)
{
	e := new AssertError(msg, location);
	vrt_eh_throw(e, location);
}

extern(C) fn vrt_eh_throw_slice_error(location: string)
{
	e := new Error("invalid array cast", location);
	vrt_eh_throw(e, location);
}

extern(C) fn vrt_eh_throw_key_not_found_error(location: string)
{
	e := new KeyNotFoundException("key does not exist", location);
	vrt_eh_throw(e, location);
}

/*!
 * Mandated by the ABI, not needed for Volt.
 */
extern(C) fn vrt_eh_delete(
	reason: _Unwind_Reason_Code,
	exceptionObject: _Unwind_Exception*)
{
}

/*!
 * Big do everything function.
 */

extern(C) fn vrt_eh_personality_v0_real(
	ver: i32,
	actions: _Unwind_Action,
	exceptionClass: u64,
	exceptionObject: _Unwind_Exception*,
	ctx: _Unwind_Context*) _Unwind_Reason_Code
{
	// Get the current instruction pointer and offset it before next
	// instruction in the current frame which threw the exception.
	pc: uintptr_t = _Unwind_GetIP(ctx) - 1;

	data: u8* = _Unwind_GetLanguageSpecificData(ctx);
	if (data is null) {
		msgs: char[][1];
		msgs[0] = cast(char[])"non region data";
		vrt_panic(cast(char[][])msgs);
		return _Unwind_Reason_Code.FATAL_PHASE1_ERROR;
	}

	// The region start is the same as the function start.
	// And all of the values in the callsite table are relative to it.
	funcStart: uintptr_t = _Unwind_GetRegionStart(ctx);
	pcOffset: uintptr_t = pc - funcStart;

	// Setup the dwarf context so we can read values.
	dwCtx: DW_Context;
	version (!OSX) {
		dwCtx.textrel = cast(void*)_Unwind_GetTextRelBase(ctx);
		dwCtx.datarel = cast(void*)_Unwind_GetDataRelBase(ctx);
		dwCtx.funcrel = cast(void*)funcStart;
	}

	// Get lpStartBase, landing pad offsets are relative to it.
	lpStartBase: uintptr_t;
	lpStartEncoding: u8;

	lpStartEncoding = dw_read_ubyte(&data);
	if (lpStartEncoding == DW_EH_PE_omit) {
		lpStartBase = funcStart;
	} else {
		msgs: char[][1];
		msgs[0] = cast(char[])"unhandled lpStartEncoding";
		vrt_panic(cast(char[][])msgs);
		return _Unwind_Reason_Code.FATAL_PHASE1_ERROR;
	}

	// Get the ttype offsets aka TypeInfo lists.
	// This can be null for empty lists.
	typeInfo: u8*;
	typeInfoEncoding: u8 = dw_read_ubyte(&data);
	typeInfoEncodingSize: size_t;

	if (typeInfoEncoding != DW_EH_PE_omit) {
		typeInfoEncodingSize = dw_encoded_size(typeInfoEncoding);
		// Calculate type info locations in emitted dwarf code which
		// were flagged by type info arguments to llvm.eh.selector
		// intrinsic.
		offset := dw_read_uleb128(&data);
		typeInfo = data + offset;
	}

	// Extract the Throwable object.
	throwable: Throwable;
	if (exceptionObject.exception_class == *cast(ulong*)VRT_EH_NAME.ptr) {
		eh := cast(vrt_eh_exception*)exceptionObject;
		throwable = eh.t;
	} else {
		// Do no type checking if this is an foreign exception.
		typeInfo = null;
	}

	// Setup the call site table.
	callSiteEncoding: u8 = dw_read_ubyte(&data);
	callSiteTableLength: uintptr_t;

	if (callSiteEncoding != DW_EH_PE_omit) {
		callSiteTableLength = dw_read_uleb128(&data);
	} else {
		msgs: char[][1];
		msgs[0] = cast(char[])"unhandled callingSiteEncoding";
		vrt_panic(cast(char[][])msgs);
		return _Unwind_Reason_Code.FATAL_PHASE1_ERROR;
	}

	callSiteTableStart: u8* = data;
	callSiteTableEnd: u8* = data + callSiteTableLength;
	actionTableStart: u8* = callSiteTableEnd;
	callSitePtr: u8* = callSiteTableStart;

	// Walk the callsite table and find the callsite which the
	// pc is in currently, then look at which actions should be
	// performed by looking in the action table.
	while (cast(size_t)callSitePtr < cast(size_t)callSiteTableEnd) {

		rangeStart := dw_read_encoded(&callSitePtr, callSiteEncoding);
		rangeEnd := dw_read_encoded(&callSitePtr, callSiteEncoding) + rangeStart;
		landingPad := dw_read_encoded(&callSitePtr, callSiteEncoding);

		actionEntry := dw_read_uleb128(&callSitePtr);

		if (rangeStart <= pcOffset && pcOffset < rangeEnd) {

			// Calculate where we should set the pc if we want to use the landing pad.
			ip: uintptr_t = lpStartBase + landingPad;

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
				actionPointer := actionTableStart + actionEntry - 1;

				// We start at 1 because 0 is cleanup.
				while (true) {
					typeOffset := dw_read_sleb128(&actionPointer);
					tmpPointer := actionPointer;
					actionOffset := dw_read_sleb128(&tmpPointer);

					if (typeOffset == 0) {
						return vrt_eh_install_finally(ip, actions, exceptionObject, ctx);
					}

					// If this is a forign exception or no type table found.
					if (typeInfo !is null) {
						ptr := typeInfo - (typeOffset * typeInfoEncodingSize);
						ti := cast(TypeInfo)dw_read_encoded(&ptr, typeInfoEncoding);
						casted := vrt_handle_cast(cast(void*)throwable, ti);
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
			}
		}
	}

	return _Unwind_Reason_Code.CONTINUE_UNWIND;
}

fn vrt_eh_install_action(
	ip: uintptr_t,
	actions: _Unwind_Action,
	switchVal: uintptr_t,
	t: Throwable,
	ctx: _Unwind_Context*) _Unwind_Reason_Code
{
	// A finally doesn't count as a handler, so we should continue.
	if (actions & _Unwind_Action.SEARCH_PHASE) {
		return _Unwind_Reason_Code.HANDLER_FOUND;
	}

	_Unwind_SetGR(ctx, vrt_eh_return_0, cast(uintptr_t)cast(void*)t);
	_Unwind_SetGR(ctx, vrt_eh_return_1, switchVal);
	_Unwind_SetIP(ctx, ip);

	return _Unwind_Reason_Code.INSTALL_CONTEXT;
}

fn vrt_eh_install_finally(
	ip: uintptr_t,
	actions: _Unwind_Action,
	exceptionObject: _Unwind_Exception*,
	ctx: _Unwind_Context*) _Unwind_Reason_Code
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
