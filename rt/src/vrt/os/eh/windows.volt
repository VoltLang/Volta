// Copyright 2013-2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
//! Exception handling using Windows' SEH.
module vrt.os.eh.windows;

version (Windows):

import core.typeinfo;
import core.exception: Throwable, Exception, Error, AssertError, KeyNotFoundException;
import core.rt.misc: vrt_panic, vrt_handle_cast;
import core.c.windows;

import vrt.ext.stdc;
import vrt.os.eh.common;


/*!
 * Per thread callback for applications getting exceptions.
 */
local lCallback : fn(Throwable, location: string);

extern(C) fn vrt_eh_set_callback(cb: fn(Throwable, location: string))
{
	lCallback = cb;
}

extern(C) fn vrt_eh_throw(t: Throwable, location: string)
{
	if (lCallback !is null) {
		lCallback(t, location);
	}

	t.throwLocation = location;

	arguments: ULONG_PTR[1];
	arguments[0] = cast(ULONG_PTR)cast(void*)t;
	RaiseException(*cast(DWORD*)VRT_EH_NAME.ptr,
		EXCEPTION_NONCONTINUABLE,
		1,
		arguments.ptr
	);

	msgs: char[][3];
	msgs[0] = cast(char[])"FAILED TO RAISE EXCEPTION";
	msgs[2] = cast(char[])t.throwLocation;
	msgs[1] = cast(char[])t.msg;
	vrt_panic(cast(char[][])msgs);
}

extern(C) fn vrt_eh_rethrow(t: Throwable)
{
	// Don't set throwLocation, and don't call lCallback.

	arguments: ULONG_PTR[1];
	arguments[0] = cast(ULONG_PTR)cast(void*)t;
	RaiseException(*cast(DWORD*)VRT_EH_NAME.ptr,
		EXCEPTION_NONCONTINUABLE,
		1,
		arguments.ptr
	);

	msgs: char[][3];
	msgs[0] = cast(char[])"FAILED TO RAISE EXCEPTION";
	msgs[2] = cast(char[])t.throwLocation;
	msgs[1] = cast(char[])t.msg;
	vrt_panic(cast(char[][])msgs);
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

@mangledName("__CxxFrameHandler3")
extern(C) fn vrt_eh_personality_v0(
	er:   PEXCEPTION_RECORD,
	ef:   PVOID,
	ctx:  PCONTEXT,
	dc:   PDISPATCHER_CONTEXT)
	EXCEPTION_DISPOSITION
{
	base        := cast(void*)dc.ImageBase;
	finfo       := getFuncInfo(base, dc.HandlerData);
	ipMap       := cast(IPMapInfo*)rvaToPtr(base, finfo.dispUnwindMap);
	tryLevel    := tryLevelFromIPMap(ipMap, finfo.nIPMapEntries, cast(i32)(dc.ControlPc - dc.ImageBase));

	if (!isVoltException(er.ExceptionCode) && !isConsolidate(er)) {
		printf("NON VOLT EXCEPTION: 0x%X\n", er.ExceptionCode);
		return EXCEPTION_DISPOSITION.ExceptionContinueSearch;
	}

	if (er.ExceptionFlags & (EH_UNWINDING|EH_EXIT_UNWIND)) {
		return EXCEPTION_DISPOSITION.ExceptionContinueSearch;
	}

	findCatchBlock(er, ctx, null, ef, dc, finfo, ef);
	return EXCEPTION_DISPOSITION.ExceptionContinueSearch;
}

private:

struct IPMapInfo
{
	ip:               i32;
	state:            i32;
}

struct FuncInfo
{
	magic:            u32;
	maxState:         u32;
	dispUnwindMap:    u32;
	nTryBlocks:       u32;
	dispTryBlockMap:  u32;
	nIPMapEntries:    u32;
	dispIPtoStateMap: u32;
	dispUnwindHelp:   u32;
	dispESTypeList:   u32;
	ehFlags:          u32;
}

struct TryInfo
{
	startLevel:       i32;
	endLevel:         i32;
	catchLevel:       i32;
	catchBlockCount:  i32;
	catchBlock:       u32;
}

struct CatchInfo
{
	flags:            u32;
	typeInfo:         u32;
	offset:           i32;
	handler:          u32;
	frame:            u32;
}

struct UnwindInfo
{
	previous: i32;
	handler:  u32;
}

enum TypeFlag
{
	Const = 1,
	Volatile,
	Reference
}

fn isVoltException(exceptionCode: DWORD) bool
{
	return exceptionCode == *cast(DWORD*)VRT_EH_NAME.ptr;
}

fn isConsolidate(er: PEXCEPTION_RECORD) bool
{
	return er.ExceptionCode == STATUS_UNWIND_CONSOLIDATE &&
		er.NumberParameters == 8 &&
		er.ExceptionInformation[0] is cast(ULONG_PTR)callCatchBlock;
}

fn findCatchBlock(
	er:          PEXCEPTION_RECORD,
	ctx:         PCONTEXT,
	untransEr:   PEXCEPTION_RECORD,
	frame:       PVOID,
	dc:          PDISPATCHER_CONTEXT,
	finfo:       FuncInfo*,
	origFrame:   PVOID
)
{
	base      := cast(void*)dc.ImageBase;

	ipMap := cast(IPMapInfo*)rvaToPtr(base, finfo.dispIPtoStateMap);
	tryLevel := tryLevelFromIPMap(ipMap, finfo.nIPMapEntries, cast(i32)(dc.ControlPc - dc.ImageBase));

	foreach (i; 0 .. finfo.nTryBlocks) {
		tinfo := cast(TryInfo*)rvaToPtr(base, finfo.dispTryBlockMap);
		tinfo  = &tinfo[i];

		if (tryLevel < tinfo.startLevel || tryLevel > tinfo.endLevel) {
			// This isn't the try block that raised the exception.
			continue;
		}

		foreach (j; 0 .. tinfo.catchBlockCount) {
			cinfo := cast(CatchInfo*)rvaToPtr(base, tinfo.catchBlock);
			cinfo  = &cinfo[j];

			typeInfo := cast(TypeInfo)rvaToPtr(base, cinfo.typeInfo);
			casted := vrt_handle_cast(cast(void*)er.ExceptionInformation[0], typeInfo);
			if (casted is null) {
				// Doesn't match the type in the catch case.
				continue;
			}
			e := cast(Exception)casted;

			dest := cast(void**)rvaToPtr(origFrame, cast(u32)cinfo.offset);
			/* Copy the exception to the stack variable for the catch block.
			 * If Volt exceptions weren't always classes (and thus always pointers)
			 * you would have to do a memcpy/memmove here.
			 * But they are, so we don't.
			 */
			*dest = casted;

			cr: EXCEPTION_RECORD;
			newCtx := new CONTEXT;  // @todo This should be fine on the stack but crashes in some configurations.
			cr.ExceptionCode            = STATUS_UNWIND_CONSOLIDATE;
			cr.ExceptionFlags           = EXCEPTION_NONCONTINUABLE;
			cr.NumberParameters         = 8;
			cr.ExceptionInformation[0]  = cast(ULONG_PTR)callCatchBlock;
			cr.ExceptionInformation[1]  = cast(ULONG_PTR)origFrame;
			cr.ExceptionInformation[2]  = cast(ULONG_PTR)finfo;
			cr.ExceptionInformation[3]  = cast(ULONG_PTR)tinfo.startLevel;
			cr.ExceptionInformation[4]  = cast(ULONG_PTR)er;
			cr.ExceptionInformation[5]  = cast(ULONG_PTR)rvaToPtr(base, cinfo.handler);
			cr.ExceptionInformation[6]  = cast(ULONG_PTR)untransEr;
			cr.ExceptionInformation[7]  = cast(ULONG_PTR)ctx;
			RtlUnwindEx(frame, cast(void*)dc.ControlPc, &cr, null, newCtx, null);
			// Regardless of how badly you mess up the RtlUnwindEx parameters, you shouldn't reach here.
			fatalError("RtlUnwindEx did not unwind.");
		}
	}
}

extern (Windows) fn callCatchBlock(er: PEXCEPTION_RECORD) PVOID
{
	frame   := er.ExceptionInformation[1];
	finfo   := cast(FuncInfo*)er.ExceptionInformation[2];
	handler := cast(fn!C(DWORD64, DWORD64) void*)cast(void*)er.ExceptionInformation[5];
	buf: char;
	retAddr := handler(0, frame);
	return retAddr;
}

fn rvaToPtr(base: void*, offset: u32) void*
{
	return cast(void*)(cast(size_t)base+offset);
}

fn tryLevelFromIPMap(ipMap: IPMapInfo*, count: u32, ip: i32) i32
{
	bottom: u32 = 0;
	max        := count - 1;

	while (bottom < max) {
		centre := bottom + (max - bottom) / 2;
		if (ipMap[centre].ip <= ip && ipMap[centre + 1].ip > ip) {
			bottom = centre;
			break;
		}
		if (ipMap[centre].ip < ip) {
			bottom = centre + 1;
		} else {
			max = centre - 1;
		}
	}

	return ipMap[bottom].state;
}

fn getFuncInfo(base: PVOID, ptr: PVOID) FuncInfo*
{
	offset := *cast(u32*)ptr;
	return cast(FuncInfo*)rvaToPtr(base, offset);
}

fn fatalError(msg: string)
{
	msgs: char[][3];
	msgs[0] = cast(char[])msg;
	vrt_panic(cast(char[][])msgs);
}
