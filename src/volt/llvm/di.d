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

		size_t size, alignment;
		pt.irType.getSizeAndAlignment(state.lp, size, alignment);
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
		LLVMValueRef diType;

		if (base.isVoid) {
			diType = null; // Yes!
		} else if (base.diType is null) {
			// Can't emit debuginfo without base debug info.
			return null;
		} else {
			diType = base.diType;
		}

		size_t size, alignment;
		pt.getSizeAndAlignment(state.lp, size, alignment);

		return LLVMDIBuilderCreatePointerType(
			state.diBuilder, diType, size, alignment,
			pt.mangledName.ptr, pt.mangledName.length);
	}

	void diVariable(State state, LLVMValueRef var, ir.Variable irVar,
	                Type type)
	{
		if (irVar.useBaseStorage) {
			auto pt = cast(PointerType) type;
			type = pt !is null ? pt.base : null;
		}

		// Can't emit debuginfo without type debug info.
		if (type is null || type.diType is null) {
			return;
		}

		auto file = diFile(state,
			state.irMod.location.filename,
			state.lp.settings.execDir);

		LLVMValueRef scope_;
		if (LLVMGetDebugMetadataVersion() == 2) {
			scope_ = state.diNode(state.diString("0x29"), file);
		} else {
			scope_ = state.diCU;
		}

		string name = irVar.mangledName;
		string link = null;
		LLVMDIBuilderCreateGlobalVariable(
			state.diBuilder,
			scope_,
			name.ptr, name.length,
			link.ptr, link.length,
			file,
			0,
			type.diType,
			false,
			var,
			null);
	}

	LLVMValueRef diStruct(State state, ir.Type t)
	{
		size_t size, alignment;
		t.getSizeAndAlignment(state.lp, size, alignment);

		return LLVMDIBuilderCreateStructType(
			state.diBuilder,
			state.diCU,
			t.mangledName.ptr, t.mangledName.length,
			state.diFile(t), cast(uint)t.location.line,
			size, alignment, 0,
			null,
			null, 0,
			null,
			0,
			null, 0);
			//t.mangledName.ptr, t.mangledName.length);
	}

	void diStructSetBody(State state, LLVMValueRef diType,
	                     ir.Variable[] elms)
	{
		auto di = new LLVMValueRef[](elms.length);
		size_t offset;

		foreach (i, elm; elms) {
			auto d = state.fromIr(elm.type).diType;
			if (d is null) {
				return;
			}

			size_t size, alignment;
			elm.type.getSizeAndAlignment(state.lp, size, alignment);

			// Adjust offset to alignment
			if (offset % alignment) {
				offset += alignment - (offset % alignment);
			}

			di[i] = LLVMDIBuilderCreateMemberType(
				state.diBuilder, state.diCU,
				elm.name.ptr, elm.name.length,
				state.diFile(elm), cast(uint)elm.location.line,
				size, alignment, offset, 0, d);

			offset += size;
		}

		LLVMDIBuilderStructSetBody(state.diBuilder, diType,
		                           di.ptr, cast(uint)di.length);
	}

	/**
	 * Used by Array and Delegates.
	 */
	void diStructSetBody(State state, Type p, Type[2] t, string[2] names)
	{
		if (p.diType is null ||
		    t[0].diType is null ||
		    t[1].diType is null) {
			return;
		}

		auto di = new LLVMValueRef[](2);
		size_t s0, s1, a0, a1;
		t[0].irType.getSizeAndAlignment(state.lp, s0, a0);
		t[1].irType.getSizeAndAlignment(state.lp, s1, a1);

		di[0] = LLVMDIBuilderCreateMemberType(
			state.diBuilder, state.diCU,
			names[0].ptr, names[0].length,
			state.diFile(p.irType), cast(uint)p.irType.location.line,
			s0, a0, 0, 0, t[0].diType);
		di[1] = LLVMDIBuilderCreateMemberType(
			state.diBuilder, state.diCU,
			names[1].ptr, names[1].length,
			state.diFile(p.irType), cast(uint)p.irType.location.line,
			s1, a1, s0, 0, t[1].diType);

		LLVMDIBuilderStructSetBody(state.diBuilder, p.diType,
		                           di.ptr, cast(uint)di.length);
	}

	LLVMValueRef diFunctionType(State state, Type ret, Type[] args)
	{
		// Add one for ret type.
		LLVMValueRef[] types = new LLVMValueRef[](args.length + 1);

		// Hold on to your butts (keep an eye on i).
		for (int i; i < args.length;) {
			auto t = args[i].diType;
			if (t is null) {
				return null;
			}

			types[++i] = t;
		}

		auto file = diFile(state, ret.irType);

		return LLVMDIBuilderCreateSubroutineType(
			state.diBuilder, file, types.ptr,
			cast(uint)types.length, 0);
	}

	alias LLVMCreateDIBuilder = lib.llvm.c.DIBuilder.LLVMCreateDIBuilder;
	alias LLVMDisposeDIBuilder = lib.llvm.c.DIBuilder.LLVMDisposeDIBuilder;

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

	LLVMValueRef diFile(State state, ir.Node n)
	{
		return state.diNode(
			state.diString(n.location.filename),
			state.diString(state.lp.settings.execDir));
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
	LLVMValueRef diStruct(State state, ir.Type t) { return null; }
	void diStructSetBody(State state, Type p, Type[2] t, string[2] names) {}
	void diStructSetBody(State state, LLVMValueRef diType, ir.Variable[] elms) {}
	LLVMValueRef diFunctionType(State state, Type ret, Type[] args) { return null; }
}


private:

/**
 * Retrive size and alignment for type in bits (not in bytes as the
 * rest of the compiler keep track of it).
 */
void getSizeAndAlignment(ir.Type t, LanguagePass lp,
                         out size_t s, out size_t a)
{
	s = cast(size_t).size(lp, t) * 8;
	a = .alignment(lp, t) * 8;
}
