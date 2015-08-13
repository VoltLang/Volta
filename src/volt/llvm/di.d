// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.di;

import ir = volt.ir.ir;
import lib.llvm.core;
import lib.llvm.c.DIBuilder;

import volt.semantic.classify : size, alignment;
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
	BaseType    = 0x24,
	FileTag     = 0x29,
	Variable    = 0x34,
}

enum DwLanguage
{
	C_plus_plus = 0x04,
	C           = 0x0C, // They went there :D
}

enum DwAte
{
	Address      = 0x01,
	Boolean      = 0x02,
	ComplexFloat = 0x03,
	Float        = 0x04,
	Signed       = 0x05,
	SignedChar   = 0x06,
	Unsigned     = 0x07,
	UnsignedChar = 0x08,
	LoUser       = 0x80,
	HiUser       = 0x81,
}

/*
 *
 * Debug info builder functions.
 *
 */

version (UseDIBuilder) {

	LLVMValueRef diCompileUnit(State state)
	{
		string file = state.irMod.location.filename;
		string dir = state.lp.settings.execDir;
		string ident = state.lp.settings.identStr;

		return LLVMDIBuilderCreateCompileUnit(state.diBuilder,
			DwLanguage.C,
			file.ptr, file.length,
			dir.ptr, dir.length,
			ident.ptr, ident.length,
			false,
			null, 0,
			0,
			null, 0,
			LLVMDebugEmission.Full,
			0,
			true);
	}

	void diFinalize(State state)
	{
		auto iver = state.diNode(
				state.diNumber(2), // Magic.
				state.diString("Debug Info Version"),
				state.diNumber(LLVMGetDebugMetadataVersion())
				);

		// This controls the dwarf version emitted.
		auto dver = state.diNode(
				state.diNumber(2), // Magic.
				state.diString("Dwarf Version"),
				state.diNumber(4)  // Emitted version.
				);

		auto picl = state.diNode(
				state.diNumber(1), // Even more magic
				state.diString("PIC Level"),
				state.diNumber(2)  // Even more magic
				);

		// This is the minimum needed to for LLVM to accept the info.
		LLVMAddNamedMetadataOperand(
			state.mod, "llvm.module.flags", iver);

		// This is not required and is a bit of magic.
		//LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", dver);
		//LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", picl);

		LLVMAddNamedMetadataOperand(
			state.mod, "llvm.ident",
			state.diNode(state.diString(
				state.lp.settings.identStr)));

		LLVMDIBuilderFinalize(state.diBuilder);
	}

	LLVMValueRef diBaseType(State state, PrimitiveType pt,
	                        ir.PrimitiveType.Kind kind)
	{
		if (state.diBuilder is null) {
			return null;
		}

		size_t size = cast(size_t).size(kind) * 8;
		size_t alignment = .alignment(state.lp, kind) * 8;
		DwAte encoding;
		string name;

		final switch(kind) with (ir.PrimitiveType.Kind) {
		case Bool:
			name = "bool";
			encoding = DwAte.Boolean;
			size = 1;
			break;
		case Byte:
			name = "byte";
			encoding = DwAte.Signed;
			break;
		case Char:
			name = "char";
			encoding = DwAte.UnsignedChar;
			break;
		case Ubyte:
			name = "ubyte";
			encoding = DwAte.Unsigned;
			break;
		case Short:
			name = "short";
			encoding = DwAte.Signed;
			break;
		case Ushort:
			name = "ushort";
			encoding = DwAte.Unsigned;
			break;
		case Wchar:
			name = "wchar";
			encoding = DwAte.UnsignedChar;
			break;
		case Int:
			name = "int";
			encoding = DwAte.Signed;
			break;
		case Uint:
			name = "uint";
			encoding = DwAte.Unsigned;
			break;
		case Dchar:
			name = "dchar";
			encoding = DwAte.UnsignedChar;
			break;
		case Long:
			name = "long";
			encoding = DwAte.Signed;
			break;
		case Ulong:
			name = "ulong";
			encoding = DwAte.Unsigned;
			break;
		case Float:
			name = "float";
			encoding = DwAte.Float;
			break;
		case Double:
			name = "double";
			encoding = DwAte.Float;
			break;
		case Void, Real:
			return null;
		}

		return LLVMDIBuilderCreateBasicType(
			state.diBuilder, name.ptr, name.length, size,
			alignment, encoding);
	}

	LLVMValueRef diPointerType(State state, ir.PointerType pt, Type base)
	{
		// Can't emit debuginfo without base debug info.
		if (base.diType is null) {
			return null;
		}

		auto size = cast(size_t).size(state.lp, pt);
		auto alignment = .alignment(state.lp, pt);

		return LLVMDIBuilderCreatePointerType(
			state.diBuilder, base.diType, size, alignment,
			pt.mangledName.ptr, pt.mangledName.length);
	}

	void diVariable(State state, LLVMValueRef var, ir.Variable irVar,
	                Type type)
	{
		// Can't emit debuginfo without type debug info.
		if (type.diType is null) {
			return;
		}

		LLVMValueRef scope_;
		if (LLVMGetDebugMetadataVersion() == 2) {
			string file = state.irMod.location.filename;
			string dir = state.lp.settings.execDir;
			scope_ = state.diNode(
				state.diString("0x29"),
				state.diFile(file, dir));
		} else {
			scope_ = state.diCU;
		}

		LLVMDIBuilderCreateGlobalVariable(
			state.diBuilder,
			scope_,
			irVar.name.ptr,
			irVar.name.length,
			irVar.mangledName.ptr,
			irVar.mangledName.length,
			null,
			0,
			type.diType,
			false,
			var,
			null);
	}

private:
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

} else {

	extern(C) LLVMDIBuilderRef LLVMCreateDIBuilder(LLVMModuleRef) { return null; }
	extern(C) void LLVMDisposeDIBuilder(LLVMDIBuilderRef builder) {}

	void diStart(State state) {}
	void diFinalize(State state) {}
	LLVMValueRef diCompileUnit(State state) { return null; }
	LLVMValueRef diBaseType(State state, PrimitiveType pt, ir.PrimitiveType.Kind kind) { return null; }
	LLVMValueRef diPointerType(State state, ir.PointerType pt, Type base) { return null; }
	void diVariable(State state, LLVMValueRef var, ir.Variable irVar, Type type) {}
}
