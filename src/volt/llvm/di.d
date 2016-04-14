// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.di;

import volt.token.location;
import ir = volt.ir.ir;
import lib.llvm.core;
import lib.llvm.c.DIBuilder : LLVMDIBuilderRef;

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

	void diSetPosition(State state, ref Location loc)
	{
		LLVMBuilderAssociatePosition(state.builder, cast(int)loc.line,
			cast(int)loc.column, state.fnState.di);
	}

	void diUnsetPosition(State state)
	{
		LLVMBuilderDeassociatePosition(state.builder);
	}

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

	LLVMValueRef diUnspecifiedType(State state, ir.Type t)
	{
		return LLVMDIBuilderCreateUnspecifiedType(
			state.diBuilder, null, 0);
	}

	LLVMValueRef diBaseType(State state, ir.PrimitiveType pt)
	{
		size_t size, alignment;
		pt.getSizeAndAlignment(state.lp, size, alignment);
		DwAte encoding;
		string name;

		final switch(pt.type) with (ir.PrimitiveType.Kind) {
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
		case Invalid:
			throw panicUnhandled(pt, "primitivetype");
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
		} else {
			assert(base !is null);
			diType = base.diType;
		}

		size_t size, alignment;
		pt.getSizeAndAlignment(state.lp, size, alignment);

		return LLVMDIBuilderCreatePointerType(
			state.diBuilder, diType, size, alignment,
			pt.mangledName.ptr, pt.mangledName.length);
	}

	LLVMValueRef diStaticArrayType(State state, ir.StaticArrayType sat,
	                               Type type)
	{
		assert(type !is null && type.diType !is null);

		size_t size, alignment;
		sat.getSizeAndAlignment(state.lp, size, alignment);

		LLVMValueRef[1] sub;
		sub[0] = LLVMDIBuilderGetOrCreateRange(
			state.diBuilder, 0, cast(long) sat.length);

		return LLVMDIBuilderCreateArrayType(
			state.diBuilder, size, alignment, type.diType,
			sub.ptr, sub.length);
	}

	void diVariable(State state, LLVMValueRef var, ir.Variable irVar,
	                Type type)
	{
		if (irVar.useBaseStorage) {
			auto pt = cast(PointerType) type;
			assert(pt !is null);
			type = pt.base;
		}

		assert(type !is null);
		assert(type.diType !is null);

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

	LLVMValueRef diUnion(State state, ir.Type t)
	{
		size_t size, alignment;
		t.getSizeAndAlignment(state.lp, size, alignment);

		string name = t.mangledName;
		string uni = null;

		return LLVMDIBuilderCreateUnionType(
			state.diBuilder,
			state.diCU,
			name.ptr, name.length,
			state.diFile(t), cast(uint)t.location.line,
			size, alignment,
			0,        // Flags
			null, 0,  // Elements
			0,        // RunTimeLang
			uni.ptr, uni.length);
	}

	void diUnionSetBody(State state, LLVMValueRef diType,
	                     ir.Variable[] elms)
	{
		diSetAggregateBody(state, diType, elms, ir.NodeType.Union);
	}

	LLVMValueRef diStruct(State state, ir.Type t)
	{
		size_t size, alignment;
		t.getSizeAndAlignment(state.lp, size, alignment);

		string name = t.mangledName;
		string uni = null;

		return LLVMDIBuilderCreateStructType(
			state.diBuilder,
			state.diCU,
			t.mangledName.ptr, t.mangledName.length,
			state.diFile(t), cast(uint)t.location.line,
			size, alignment,
			0,        // Flags
			null,     // DerivedFrom
			null, 0,  // Elements
			null,     // VTableHolder
			0,        // RunTimeLang
			uni.ptr, uni.length);
	}

	void diStructSetBody(State state, LLVMValueRef diType,
	                     ir.Variable[] elms)
	{
		diSetAggregateBody(state, diType, elms, ir.NodeType.Struct);
	}

	void diSetAggregateBody(State state, LLVMValueRef diType,
	                        ir.Variable[] elms, ir.NodeType kind)
	{
		auto di = new LLVMValueRef[](elms.length);
		size_t offset;

		foreach (i, elm; elms) {
			auto d = state.fromIr(elm.type).diType;
			assert(d !is null);

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

			if (kind != ir.NodeType.Union) {
				offset += size;
			}
		}

		LLVMDIBuilderStructSetBody(state.diBuilder, diType,
		                           di.ptr, cast(uint)di.length);
	}

	/**
	 * Used by Array and Delegates.
	 */
	void diStructSetBody(State state, Type p, Type[2] t, string[2] names)
	{
		assert(p !is null && p.diType !is null);
		assert(t[0] !is null && t[0].diType !is null);
		assert(t[1] !is null && t[1].diType !is null);

		auto di = new LLVMValueRef[](2);
		size_t s0, s1, a0, a1, offset;
		t[0].irType.getSizeAndAlignment(state.lp, s0, a0);
		t[1].irType.getSizeAndAlignment(state.lp, s1, a1);


		// Adjust offset to alignment
		if (s0 % a1) {
			offset = s0 + a1 - (offset % a1);
		} else {
			offset = s0;
		}

		di[0] = LLVMDIBuilderCreateMemberType(
			state.diBuilder, state.diCU,
			names[0].ptr, names[0].length,
			state.diFile(p.irType), cast(uint)p.irType.location.line,
			s0, a0, 0, 0, t[0].diType);
		di[1] = LLVMDIBuilderCreateMemberType(
			state.diBuilder, state.diCU,
			names[1].ptr, names[1].length,
			state.diFile(p.irType), cast(uint)p.irType.location.line,
			s1, a1, offset, 0, t[1].diType);

		LLVMDIBuilderStructSetBody(state.diBuilder, p.diType,
		                           di.ptr, cast(uint)di.length);
	}

	LLVMValueRef diFunctionType(State state, Type ret, Type[] args,
	                            string mangledName, out LLVMValueRef diCallType)
	{
		// Add one for ret type.
		LLVMValueRef[] types = new LLVMValueRef[](args.length + 1);

		// Ret goes first, this can be null because of VoidType.
		types[0] = ret.diType;

		// Hold on to your butts (keep an eye on i).
		for (int i; i < args.length; i++) {

			assert(args[i] !is null && args[i].diType !is null);

			types[i + 1] = args[i].diType;
		}

		auto file = diFile(state, ret.irType);

		diCallType = LLVMDIBuilderCreateSubroutineType(
			state.diBuilder, file, types.ptr,
			cast(uint)types.length, 0);

		size_t size, alignment;
		state.voidPtrType.irType.getSizeAndAlignment(
			state.lp, size, alignment);

		return LLVMDIBuilderCreatePointerType(
			state.diBuilder, diCallType, size, alignment,
			mangledName.ptr, mangledName.length);
	}

	LLVMValueRef diFunction(State state, ir.Function irFn,
	                        LLVMValueRef func, FunctionType ft)
	{
		auto file = diFile(state,
			irFn.location.filename,
			state.lp.settings.execDir);
		LLVMValueRef _scope = file;
		string name = irFn.mangledName;
		string link = null;

		assert(file !is null && _scope !is null);

		return LLVMDIBuilderCreateFunction(state.diBuilder, _scope,
			name.ptr, name.length, null, 0,
			file, cast(uint) irFn.location.line, ft.diCallType,
			false, true, cast(uint) irFn.location.line, 0,
			false, func, null, null);
	}

	void diAutoVariable(State state, ir.Variable var,
	                    LLVMValueRef val, Type type)
	{
		string name = var.name;
		auto file = diFile(state, var);
		auto loc = diLocation(state, state.fnState.di, var.location);
		auto expr = LLVMDIBuilderCreateExpression(
			state.diBuilder, null, 0);

		auto valinfo = LLVMDIBuilderCreateAutoVariable(
			state.diBuilder, state.fnState.di,
			name.ptr, name.length,
			file, cast(uint) var.location.line,
			type.diType,
			false, // AlwaysPreserve
			0);
		LLVMDIBuilderInsertDeclare(
			state.diBuilder,
			val,
			valinfo,
			expr, // Expr
			loc, // DL
			state.block);
	}

	void diParameterVariable(State state, ir.FunctionParam var,
	                         LLVMValueRef val, Type type)
	{
		string name = var.name;
		auto file = diFile(state, var);
		auto loc = diLocation(state, state.fnState.di, var.location);
		auto expr = LLVMDIBuilderCreateExpression(
			state.diBuilder, null, 0);

		auto valinfo = LLVMDIBuilderCreateParameterVariable(
			state.diBuilder, state.fnState.di,
			name.ptr, name.length,
			cast(int) var.index + 1,
			file, cast(uint) var.location.line,
			type.diType,
			false, // AlwaysPreserve
			0);
		LLVMDIBuilderInsertDeclare(
			state.diBuilder,
			val,
			valinfo,
			expr, // Expr
			loc, // DL
			state.block);
	}

	alias LLVMCreateDIBuilder = lib.llvm.c.DIBuilder.LLVMCreateDIBuilder;
	alias LLVMDisposeDIBuilder = lib.llvm.c.DIBuilder.LLVMDisposeDIBuilder;

private:
	LLVMValueRef diLocation(State state, LLVMValueRef _scope,
	                        ref Location loc)
	{
		return LLVMDIBuilderCreateLocation(
			state.diBuilder, cast(uint) loc.line,
			cast(ushort) loc.column, _scope);
	}

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
		return LLVMDIBuilderCreateFile(state.diBuilder,
			file.ptr, file.length, dir.ptr, dir.length);
	}

	LLVMValueRef diFile(State state, ir.Node n)
	{
		return diFile(state,
			n.location.filename,
			state.lp.settings.execDir);
	}

} else {

	extern(C) LLVMDIBuilderRef LLVMCreateDIBuilder(LLVMModuleRef) { return null; }
	extern(C) void LLVMDisposeDIBuilder(LLVMDIBuilderRef builder) {}

	void diSetPosition(State, ref Location) {}
	void diUnsetPosition(State) {}
	void diStart(State state) {}
	void diFinalize(State state) {}
	LLVMValueRef diCompileUnit(State state) { return null; }
	LLVMValueRef diUnspecifiedType(State state, ir.Type t) { return null; }
	LLVMValueRef diBaseType(State state, ir.PrimitiveType pt) { return null; }
	LLVMValueRef diPointerType(State state, ir.PointerType pt, Type base) { return null; }
	LLVMValueRef diStaticArrayType(State, ir.StaticArrayType, Type) { return null; }
	void diVariable(State state, LLVMValueRef var, ir.Variable irVar, Type type) {}
	LLVMValueRef diUnion(State state, ir.Type t) { return null; }
	void diUnionSetBody(State state, LLVMValueRef diType, ir.Variable[] elms) {}
	LLVMValueRef diStruct(State state, ir.Type t) { return null; }
	void diStructSetBody(State state, Type p, Type[2] t, string[2] names) {}
	void diStructSetBody(State state, LLVMValueRef diType, ir.Variable[] elms) {}
	LLVMValueRef diFunctionType(State state, Type ret, Type[] args,
	                            string mangledName, out LLVMValueRef diCallType) { return null; }
	LLVMValueRef diFunction(State state, ir.Function irFn,
	                        LLVMValueRef func, FunctionType ft) { return null; }
	void diAutoVariable(State state, ir.Variable var, LLVMValueRef val, Type type) {}
	void diParameterVariable(State state, ir.FunctionParam var, LLVMValueRef val, Type type) {}
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
