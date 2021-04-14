/*#D*/
// Copyright 2015-2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Debug info generation code.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.debugInfo;

import ir = volta.ir;

import volta.ir.location;

import lib.llvm.core;
import lib.llvm.c.DebugInfo;

import volt.errors;
import volt.semantic.classify : size, alignment;
import volt.llvm.dwarf;
import volt.llvm.interfaces;


/*
 *
 * Debug info builder functions.
 *
 */

version (LLVMVersion7AndAbove) {

	/*
	 *
	 * Builder functions.
	 *
	 */

	LLVMDIBuilderRef diCreateDIBuilder(LLVMModuleRef mod)
	{
		return lib.llvm.c.DebugInfo.LLVMCreateDIBuilder(mod);
	}

	void diDisposeDIBuilder(ref LLVMDIBuilderRef b)
	{
		if (b is null) {
			return;
		}

		lib.llvm.c.DebugInfo.LLVMDisposeDIBuilder(b);
		b = null;
	}


	/*
	 *
	 * Location functions.
	 *
	 */

	void diSetPosition(State state, ref Location loc)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		auto l = state.diLocationAsValue(/*#ref*/loc, state.fnState.di);
		LLVMSetCurrentDebugLocation(state.builder, l);
	}

	void diUnsetPosition(State state)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		LLVMSetCurrentDebugLocation(state.builder, null);
	}


	/*
	 *
	 * Builder and compile unit functions.
	 *
	 */

	LLVMMetadataRef diCompileUnit(State state)
	{
		if (state.irMod.forceNoDebug) {
			return null;
		}
		auto filename = state.irMod.loc.filename;
		auto ident = state.identStr;
		auto file = state.diFile(filename, state.currentWorkingDir);

		version (LLVMVersion11AndAbove) {
			return LLVMDIBuilderCreateCompileUnit(state.diBuilder,
					LLVMDWARFSourceLanguage.C,  // Lang
					file,                       // FileRef
					ident.ptr, ident.length,    // Producer
					false,                      // isOptimized
					null, 0,                    // Flags
					0,                          // RuntimeVer
					null, 0,                    // SplitName
					LLVMDWARFEmissionKind.Full, // Kind
					0,                          // DWOId
					false,                      // SplitDebugInlining
					true,                       // DebugInfoForProfiling
					null,                       // SysRoot
					0,                          // SysRootLen
					null,                       // SDK
					0                           // SDKLen
				);
		} else {
			return LLVMDIBuilderCreateCompileUnit(state.diBuilder,
					LLVMDWARFSourceLanguage.C,  // Lang
					file,                       // FileRef
					ident.ptr, ident.length,    // Producer
					false,                      // isOptimized
					null, 0,                    // Flags
					0,                          // RuntimeVer
					null, 0,                    // SplitName
					LLVMDWARFEmissionKind.Full, // Kind
					0,                          // DWOId
					false,                      // SplitDebugInlining
					true                        // DebugInfoForProfiling
				);
		}
	}

	void diFinalize(State state)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		// Compiler name, again.
		auto cname = state.diNode(state.diString(state.identStr));

		// Add the name of the compiler as well.
		LLVMAddNamedMetadataOperand(state.mod, "llvm.ident", cname);

		// The LLVM internal debug info API version.
		auto iver = state.diNode(
			state.diNumber(2), // Magic.
			state.diString("Debug Info Version"),
			state.diNumber(3)  // LLVM version.
			);

		// This is the minimum needed to for LLVM to accept the info.
		LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", iver);

		if (state.target.platform == Platform.MSVC) {
			auto cv = state.diNode(
				state.diNumber(2), // Magic.
				state.diString("CodeView"),
				state.diNumber(1)  // Codeview version?
			);
			auto wsz = state.diNode(
				state.diNumber(1), // Magic.
				state.diString("wchar_size"),
				state.diNumber(2)  // wchar_size size?
			);
			auto pl = state.diNode(
				state.diNumber(7), // Magic.
				state.diString("PIC Level"),
				state.diNumber(2)  // PIC Level?
			);

			LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", cv);
			LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", wsz);
			LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", pl);
		} else {
			// This controls the dwarf version emitted.
			auto dver = state.diNode(
					state.diNumber(2), // Magic.
					state.diString("Dwarf Version"),
					state.diNumber(4)  // Emitted version.
					);

			// This is just nice to have, but not required.
			LLVMAddNamedMetadataOperand(state.mod, "llvm.module.flags", dver);
		}

		// One final thing.
		LLVMDIBuilderFinalize(state.diBuilder);
	}


	/*
	 *
	 * Type functions.
	 *
	 */

	LLVMMetadataRef diUnspecifiedType(State state, Type t)
	{
		if (state.irMod.forceNoDebug) {
			return null;
		}
		auto name = t.irType.mangledName;

		return LLVMDIBuilderCreateUnspecifiedType(
			state.diBuilder,        // Builder
			name.ptr, name.length); // Name
	}

	LLVMMetadataRef diBaseType(State state, ir.PrimitiveType pt)
	{
		if (state.irMod.forceNoDebug) {
			return null;
		}
		size_t size, alignment;
		pt.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);
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
			state.diBuilder,       // Builder
			name.ptr, name.length, // Name
			size,                  // SizeInBits
			cast(uint) encoding,   // Encoding
			LLVMDIFlags.Zero);     // Flags
	}

	LLVMMetadataRef diPointerType(State state, ir.PointerType pt, Type base)
	{
		if (state.irMod.forceNoDebug) {
			return null;
		}
		assert(base !is null);

		LLVMMetadataRef diType;
		uint addrSpace = 0;

		if (base.isVoid()) {
			diType = null; // Yes!
		} else {
			assert(base.diType !is null);
			diType = base.diType;
		}

		size_t size, alignment;
		pt.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

		auto name = pt.mangledName;

		return LLVMDIBuilderCreatePointerType(
			state.diBuilder,            // Builder
			diType,                     // PionteeTy
			size, cast(uint) alignment, // SizeInBits, AlignInBits
			0,                          // AddresSpace
			name.ptr, name.length);     // Name
	}

	LLVMMetadataRef diStaticArrayType(State state, ir.StaticArrayType sat,
	                                  Type type)
	{
		if (state.irMod.forceNoDebug) {
			return null;
		}
		assert(type !is null && type.diType !is null);

		size_t size, alignment;
		sat.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

		LLVMMetadataRef[1] sub;
		sub[0] = LLVMDIBuilderGetOrCreateSubrange(
			state.diBuilder, 0, cast(long) sat.length);

		return LLVMDIBuilderCreateArrayType(
			state.diBuilder,                 // Builder
			size, cast(uint) alignment,      // SizeInBits, AlignInBits
			type.diType,                     // Ty
			sub.ptr, cast(uint) sub.length); // Subscripts
	}

	/*!
	 * Create a forward declared struct.
	 */
	LLVMMetadataRef diForwardDeclareAggregate(State state, ir.Type t)
	{
		if (state.irMod.forceNoDebug) {
			return null;
		}

		size_t size, alignment;
		t.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

		auto file = state.diFile(t);
		auto name = t.mangledName;

		return LLVMDIBuilderCreateReplaceableCompositeType(
			state.diBuilder,            // Builder
			0,                          // Tag
			name.ptr, name.length,      // Name
			state.diCU,                 // Scope
			file, cast(uint)t.loc.line, // File, Line
			0,                          // RuntimeLang
			size, cast(uint)alignment,  // SizeInBits, AlignInBits
			LLVMDIFlags.Zero,           // Flags
			null, 0);                   // UnqiueId
	}

	/*!
	 * Create a union that also replaces the old given diType.
	 *
	 * @param[inout] diType Return type, if given as none null replace it
	 *                      with the old one.
	 */
	void diUnionReplace(State state, ref LLVMMetadataRef diType, Type p,
	                    ir.Variable[] elms)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		auto di = new LLVMMetadataRef[](elms.length);

		foreach (i, elm; elms) {
			auto et = state.fromIr(elm.type);
			assert(et !is null && et.diType !is null);
			auto d = et.diType;

			size_t size, alignment;
			elm.type.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

			auto file = state.diFile(elm);
			auto line = cast(uint) elm.loc.line;

			di[i] = LLVMDIBuilderCreateMemberType(
				state.diBuilder,               // Builder   
				state.diCU,                    // Scope
				elm.name.ptr, elm.name.length, // Elements
				file, line,                    // File, Line
				size, cast(uint) alignment,    // SizeInBits, AlignInBits
				0,                             // Offset
				LLVMDIFlags.Zero, d);          // Flags, Ty
		}

		size_t size, alignment;
		p.irType.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

		auto file = state.diFile(p.irType);
		auto name = p.irType.mangledName;
		auto line = cast(uint) p.irType.loc.line;

		auto u = LLVMDIBuilderCreateUnionType(
			state.diBuilder,              // Builder
			state.diCU,                   // Scope
			name.ptr, name.length,        // Name
			file, line,                   // File, Line
			size, cast(uint) alignment,   // SizeInBits, AlignInBits
			LLVMDIFlags.Zero,             // Flags
			di.ptr, cast(uint) di.length, // Elements
			0,                            // RunTimeLang
			null, 0);                     // UniqueId

		if (diType !is null) {
			LLVMMetadataReplaceAllUsesWith(diType, u);
		}
		diType = u;
	}

	/*!
	 * Create a struct that also replaces the old given diType.
	 *
	 * @param[inout] diType Return type, if given as none null replace it
	 *                      with the old one.
	 */
	void diStructReplace(State state, ref LLVMMetadataRef diType,
	                     ir.Type irType, ir.Variable[] elms)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		auto di = new LLVMMetadataRef[](elms.length);
		size_t offset;

		foreach (i, elm; elms) {
			auto et = state.fromIr(elm.type);
			assert(et !is null && et.diType !is null);
			auto d = et.diType;

			size_t size, alignment;
			elm.type.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

			// Adjust offset to alignment.
			if (offset % alignment) {
				offset += alignment - (offset % alignment);
			}

			auto file = state.diFile(elm);
			auto line = cast(uint) elm.loc.line;

			di[i] = LLVMDIBuilderCreateMemberType(
				state.diBuilder,               // Builder   
				state.diCU,                    // Scope
				elm.name.ptr, elm.name.length, // Elements
				file, line,                    // File, Line
				size, cast(uint) alignment,    // SizeInBits, AlignInBits
				offset,                        // Offset
				LLVMDIFlags.Zero, d);          // Flags, Ty

			offset += size;
		}

		size_t size, alignment;
		irType.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

		
		auto file = state.diFile(irType);
		auto line = cast(uint)irType.loc.line;
		auto name = irType.mangledName;

		LLVMMetadataRef st = LLVMDIBuilderCreateStructType(
			state.diBuilder,              // Builder
			state.diCU,                   // Scope
			name.ptr, name.length,        // Name
			file, line,                   // File, Line
			size, cast(uint) alignment,   // SizeInBits, AlignInBits
			LLVMDIFlags.Zero,             // Flags
			null,                         // DerivedFrom
			di.ptr, cast(uint) di.length, // Elements
			0,                            // RunTimeLang
			null,                         // VTableHolder
			null, 0);                     // UniqueId

		if (diType !is null) {
			LLVMMetadataReplaceAllUsesWith(diType, st);
		}
		/*out*/diType = st;
	}

	/*!
	 * Used by Array and Delegates, as such is not inserted into a scope.
	 *
	 * @param[inout] diType Return type, if given as none null replace it
	 *                      with the old one.
	 */
	void diStructReplace(State state, ref LLVMMetadataRef diType,
	                     Type p, Type[2] t, string[2] names)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		assert(p !is null && p.diType !is null);
		assert(t[0] !is null && t[0].diType !is null);
		assert(t[1] !is null && t[1].diType !is null);

		LLVMMetadataRef[2] di;
		size_t s0, s1, a0, a1, offset, size, alignment;
		p.irType.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);
		t[0].irType.getSizeAndAlignment(state.target, /*#out*/s0, /*#out*/a0);
		t[1].irType.getSizeAndAlignment(state.target, /*#out*/s1, /*#out*/a1);

		// Adjust offset to alignment
		if (s0 % a1) {
			offset = s0 + a1 - (offset % a1);
		} else {
			offset = s0;
		}

		di[0] = LLVMDIBuilderCreateMemberType(
			state.diBuilder,                // Builder
			null,                           // Scope
			names[0].ptr, names[0].length,  // Name
			null, 0,                        // File, Line
			s0, cast(uint) a0, 0,           // Size, align, offset
			LLVMDIFlags.Zero, t[0].diType); // Flags, Ty
		di[1] = LLVMDIBuilderCreateMemberType(
			state.diBuilder,                // Builder
			null,                           // Scope
			names[1].ptr, names[1].length,  // Name
			null, 0,                        // File, Line
			s1, cast(uint) a1, offset,      // Size, align, offset
			LLVMDIFlags.Zero, t[1].diType); // Flags, Ty

		auto name = p.irType.mangledName;

		LLVMMetadataRef st = LLVMDIBuilderCreateStructType(
			state.diBuilder,              // Builder
			null,                         // Scope
			name.ptr, name.length,        // Name
			null, 0,                      // File, Line
			size, cast(uint)alignment,    // SizeInBits, AlignInBits
			LLVMDIFlags.Zero,             // Flags,
			null,                         // DerivedFrom
			di.ptr, cast(uint) di.length, // Elements
			0,                            // RunTimeLang
			null,                         // VTableHolder
			null, 0);                     // UniqueId

		if (diType !is null) {
			LLVMMetadataReplaceAllUsesWith(diType, st);
		}
		/*out*/diType = st;
	}

	LLVMMetadataRef diFunctionType(State state, Type ret, Type[] args,
	                               string name,
	                               out LLVMMetadataRef diCallType)
	{
		if (state.irMod.forceNoDebug) {
			return null;
		}

		// Add one for ret type.
		auto types = new LLVMMetadataRef[](args.length + 1);

		// Ret goes first, this can be null because of VoidType.
		types[0] = ret.diType;

		// Hold on to your butts (keep an eye on i).
		for (size_t i; i < args.length; i++) {

			assert(args[i] !is null);
			assert(args[i].diType !is null);

			types[i + 1] = args[i].diType;
		}

		auto file = diFile(state, ret.irType);

		/*out*/diCallType = LLVMDIBuilderCreateSubroutineType(
			state.diBuilder, file, types.ptr,
			cast(uint)types.length, LLVMDIFlags.Zero);

		size_t size, alignment;
		state.voidPtrType.irType.getSizeAndAlignment(
			state.target, /*#out*/size, /*#out*/alignment);

		return LLVMDIBuilderCreatePointerType(
			state.diBuilder,            // Builder
			diCallType,                 // PionteeTy
			size, cast(uint) alignment, // SizeInBits, AlignInBits
			0,                          // AddresSpace
			name.ptr, name.length);     // Name
	}


	/*
	 *
	 * Declarations functions.
	 *
	 */

	LLVMMetadataRef diFunction(State state, ir.Function irFn,
	                           LLVMValueRef func, FunctionType ft)
	{
		if (state.irMod.forceNoDebug) {
			return null;
		}

		// @todo Maybe add a better name here, dotted.name.perhaps?
		auto name = irFn.mangledName;
		auto file = diFile(state, irFn);
		auto line = cast(uint) irFn.loc.line;

		assert(file !is null);

		auto ret = LLVMDIBuilderCreateFunction(
			state.diBuilder,          // Builder
			file,                     // Scope
			name.ptr, name.length,    // Name
			null, 0,                  // LinkageName
			file, line,               // File, LineNo
			ft.diCallType,            // Ty
			false,                    // IsLocalToUnit
			true,                     // IsDefinition
			cast(uint) irFn.loc.line, // ScopeLine
			LLVMDIFlags.Zero,         // Flags
			false);                   // IsOptimized
		LLVMSetSubprogram(func, ret);
		return ret;
	}

	void diGlobalVariable(State state, ir.Variable var, Type type,
	                      LLVMValueRef val)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		if (var.useBaseStorage) {
			auto pt = cast(PointerType) type;
			assert(pt !is null);
			type = pt.base;
		}

		assert(type !is null);
		assert(type.diType !is null);

		size_t size, alignment;
		type.irType.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

		auto file = diFile(state, state.irMod);
		auto scope_ = state.diCU;
		auto expr = LLVMDIBuilderCreateExpression(
			state.diBuilder, null, 0);

		string name = var.name;
		string link = var.mangledName;

		LLVMDIBuilderCreateGlobalVariableExpression(
			state.diBuilder,                 // Builder
			scope_,                          // Scope
			name.ptr, name.length,           // Name
			link.ptr, link.length,	         // Linkage
			file, cast(uint) var.loc.line,   // File, Line
			type.diType,                     // Ty
			var.access == ir.Access.Private, // LocalToUnit
			expr,                            // Expr
			null,                            // Decl
			cast(uint) alignment);           // AlignInBits
	}

	void diLocalVariable(State state, ir.Variable var, Type type,
	                     LLVMValueRef val)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		string name = var.name;
		size_t size, alignment;
		type.irType.getSizeAndAlignment(state.target, /*#out*/size, /*#out*/alignment);

		auto file = diFile(state, var);
		auto loc = diLocation(state, /*#ref*/var.loc, state.fnState.di);
		auto expr = LLVMDIBuilderCreateExpression(
			state.diBuilder, null, 0);

		auto valinfo = LLVMDIBuilderCreateAutoVariable(
			state.diBuilder,               // Builder
			state.fnState.di,              // Scope
			name.ptr, name.length,         // Name
			file, cast(uint) var.loc.line, // File, Line
			type.diType,                   // Ty
			false,                         // AlwaysPreserve
			LLVMDIFlags.Zero,              // Flags
			cast(uint) alignment);         // Alignment

		LLVMDIBuilderInsertDeclareBefore(
			state.diBuilder,        // Builder
			val,                    // Storage
			valinfo,                // VarInfo
			expr,                   // Expr
			loc,                    // DebugLoc
			state.fnState.entryBr); // Instr
	}

	void diParameterVariable(State state, ir.FunctionParam var, Type type,
	                         LLVMValueRef val)
	{
		if (state.irMod.forceNoDebug) {
			return;
		}
		// XXX Bug in LLVM :(
		string name = (var.name ~ '\0')[0 .. var.name.length];

		auto file = diFile(state, var);
		auto loc = diLocation(state, /*#ref*/var.loc, state.fnState.di);
		auto expr = LLVMDIBuilderCreateExpression(
			state.diBuilder, null, 0);

		auto valinfo = LLVMDIBuilderCreateParameterVariable(
			state.diBuilder,                // Builder
			state.fnState.di,               // Scope
			name.ptr, name.length,          // Name
			cast(uint) (var.index + 1),     // ArgNo
			file, cast(uint) var.loc.line,  // File, Line
			type.diType,                    // Ty
			false,                          // AlwaysPreserve
			LLVMDIFlags.Zero);              // Flags

		LLVMDIBuilderInsertDeclareBefore(
			state.diBuilder,        // Builder
			val,                    // Storage
			valinfo,                // VarInfo
			expr,                   // Expr
			loc,                    // DebugLoc
			state.fnState.entryBr); // Instr
	}


private:
	LLVMMetadataRef diLocation(State state, ref Location loc,
	                           LLVMMetadataRef _scope)
	{
		return LLVMDIBuilderCreateDebugLocation(state.context,
			cast(uint) loc.line,   // Line
			cast(uint) loc.column, // Column
			_scope,                // Scope
			null);                 // InlinedAt
	}

	LLVMValueRef diLocationAsValue(State state, ref Location loc,
	                               LLVMMetadataRef _scope)
	{
		auto l = diLocation(state, /*#ref*/loc, _scope);
		return LLVMMetadataAsValue(state.context, l);
	}

	LLVMValueRef diString(State state, const(char)[] str)
	{
		return LLVMMDStringInContext(
				state.context, str.ptr, cast(uint)str.length);
	}

	LLVMValueRef diNode(State state, LLVMValueRef[] val...)
	{
		return LLVMMDNodeInContext(state.context, val.ptr, cast(uint)val.length);
	}

	LLVMValueRef diNumber(State state, int val)
	{
		return state.intType.fromNumber(state, val);
	}

	LLVMMetadataRef diFile(State state, const(char)[] file, const(char)[] dir)
	{
		return LLVMDIBuilderCreateFile(state.diBuilder,
			file.ptr, file.length, dir.ptr, dir.length);
	}

	LLVMMetadataRef diFile(State state, ir.Node n)
	{
		if (n is null || n.loc.filename.length == 0) {
			assert(false, ir.nodeToString(n.nodeType));
		}
		return diFile(state,
			n.loc.filename,
			state.currentWorkingDir);
	}

} else {

	LLVMDIBuilderRef diCreateDIBuilder(LLVMModuleRef mod) { return null; }
	void diDisposeDIBuilder(ref LLVMDIBuilderRef) {}

	void diSetPosition(State state, ref Location loc) {}
	void diUnsetPosition(State state) {}
	LLVMMetadataRef diCompileUnit(State state) { return null; }
	void diFinalize(State state) {}
	LLVMMetadataRef diUnspecifiedType(State state, Type t) { return null; }
	LLVMMetadataRef diBaseType(State state, ir.PrimitiveType pt) { return null; }
	LLVMMetadataRef diPointerType(State state, ir.PointerType pt, Type base) { return null; }
	LLVMMetadataRef diStaticArrayType(State state, ir.StaticArrayType sat,
	                               Type type) { return null; }
	LLVMMetadataRef diForwardDeclareAggregate(State state, ir.Type t) { return null; }
	void diUnionReplace(State state, ref LLVMMetadataRef diType, Type p,
	                    ir.Variable[] elms) {}
	void diStructReplace(State state, ref LLVMMetadataRef diType,
	                     ir.Type irType, ir.Variable[] elms) {}
	void diStructReplace(State state, ref LLVMMetadataRef diType,
	                     Type p, Type[2] t, string[2] names) {}
	LLVMMetadataRef diFunctionType(State state, Type ret, Type[] args,
	                               string mangledName,
	                               out LLVMMetadataRef diCallType) { return null; }
	LLVMMetadataRef diFunction(State state, ir.Function irFn,
	                           LLVMValueRef func, FunctionType ft) { return null; }
	void diGlobalVariable(State state, ir.Variable var, Type type,
	                      LLVMValueRef val) {}
	void diLocalVariable(State state, ir.Variable var, Type type,
	                     LLVMValueRef val) {}
	void diParameterVariable(State state, ir.FunctionParam var, Type type,
	                         LLVMValueRef val) { }
}


private:

/*!
 * Retrive size and alignment for type in bits (not in bytes as the
 * rest of the compiler keep track of it).
 */
void getSizeAndAlignment(ir.Type t, TargetInfo target,
                         out size_t s, out size_t a)
{
	s = cast(size_t).size(target, t) * 8;
	a = .alignment(target, t) * 8;
}
