// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.dibuilder;

import ir = volt.ir.ir;
import lib.llvm.core;

import volt.llvm.interfaces;

import volt.errors;

/*
 *
 * Dwarf enums.
 *
 */

enum DwTag
{
	CompileUnit = 0x11,
}

enum DwLanguage
{
	C = 0x0C, // They went there :D
}

enum DwOptimized
{
	No = false,
	Yes = true,
}

enum DwDebugType
{
	Full = 1,      ///< Full types debug info.
	LinesOnly = 2, ///< Only line tables.

}

/*
 *
 * Debug info builder functions.
 *
 */

LLVMValueRef diString(State state, const(char)[] str)
{
	return LLVMMDStringInContext(
		state.context, str.ptr, cast(int)str.length);
}

LLVMValueRef diNode(State state, LLVMValueRef[] val...)
{
	return LLVMMDNodeInContext(state.context, val.ptr, cast(int)val.length);
}

LLVMValueRef diNumber(State state, int val)
{
	return state.intType.fromNumber(state, val);
}

LLVMValueRef diFile(State state, const(char)[] file, const(char)[] dir)
{
	return state.diNode(state.diString(file), state.diString(dir));
}

void diCompileUnit(State state)
{
	string ident = "Volta version 0.0.1";

	auto str = diCompileUnitString(
		DwTag.CompileUnit,
		DwLanguage.C,
		ident,
		DwOptimized.No,
		"",
		0,
		"",
		DwDebugType.Full);

	auto file = state.diFile(
		state.irMod.location.filename,
		state.lp.settings.execDir);

	auto cu = state.diNode(
		state.diString(str),
		file,
		state.diNode(),
		state.diNode(),
		state.diNode(),
		state.diNode(),
		state.diNode()
	);

	auto dver = state.diNode(
		state.diNumber(2), // Magic
		state.diString("Dwarf Version"),
		state.diNumber(2)  // Magic
	);

	auto iver = state.diNode(
		state.diNumber(2), // Magic
		state.diString("Debug Info Version"),
		state.diNumber(2)  // Magic
	);

	auto picl = state.diNode(
		state.diNumber(1), // Even more magic
		state.diString("PIC Level"),
		state.diNumber(2)  // Even more magic
	);

	// The first 3 are the minimum needed for LLVM not to complain.
	LLVMAddNamedMetadataOperand(state.mod, "llvm.dbg.cu", cu);
	LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", dver);
	LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", iver);

	// This is not required and I have no idea what it does.
	//LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", picl);

	LLVMAddNamedMetadataOperand(
		state.mod, "llvm.ident", state.diNode(state.diString(ident)));
}

/*
 *
 * String functions.
 *
 */

/**
 * Creates a DW_TAG_CompileUnit tag string.
 */
string diCompileUnitString(
	DwTag dwarfTagType,
	DwLanguage dwarfLanguage,
	string ident,
	DwOptimized optimized,
	string flags,
	int runtimeVersion,
	string splitDebugInfoFile,
	DwDebugType dwarfDebugType)
{
	return format("0x%x\00%s\00%s\00%s\00%s\00%s\00%s\00%s",
		cast(int)dwarfTagType,
		cast(int)dwarfLanguage,
		ident,
		cast(int)optimized,
		flags,
		cast(int)runtimeVersion,
		splitDebugInfoFile,
		cast(int)dwarfDebugType);
}
