/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.DebugInfo;

public import lib.llvm.c.Types;


alias LLVMDWARFTypeEncoding = uint;
alias LLVMMetadataKind = uint;


extern(C):

//#--- Auto generated below ---#
enum LLVMDIFlags {
	Zero = 0,
	Private = 1,
	Protected = 2,
	Public = 3,
	FwdDecl = 1 << 2,
	AppleBlock = 1 << 3,
	ReservedBit4 = 1 << 4,
	Virtual = 1 << 5,
	Artificial = 1 << 6,
	Explicit = 1 << 7,
	Prototyped = 1 << 8,
	ObjcClassComplete = 1 << 9,
	ObjectPointer = 1 << 10,
	Vector = 1 << 11,
	StaticMember = 1 << 12,
	LValueReference = 1 << 13,
	RValueReference = 1 << 14,
	Reserved = 1 << 15,
	SingleInheritance = 1 << 16,
	MultipleInheritance = 2 << 16,
	VirtualInheritance = 3 << 16,
	IntroducedVirtual = 1 << 18,
	BitField = 1 << 19,
	NoReturn = 1 << 20,
	TypePassByValue = 1 << 22,
	TypePassByReference = 1 << 23,
	EnumClass = 1 << 24,
	FixedEnum = EnumClass,
	Thunk = 1 << 25,
	NonTrivial = 1 << 26,
	BigEndian = 1 << 27,
	LittleEndian = 1 << 28,
	IndirectVirtualBase = (1 << 2) | (1 << 5),
	Accessibility = Private | Protected | Public,
	PtrToMemberRep = SingleInheritance | MultipleInheritance | VirtualInheritance,
}
enum LLVMDWARFEmissionKind {
	None = 0,
	Full = 1,
	LineTablesOnly = 2,
}
enum LLVMDWARFMacinfoRecordType {
	Define = 0x01,
	Macro = 0x02,
	StartFile = 0x03,
	EndFile = 0x04,
	VendorExt = 0xff,
}
version(LLVMVersion20AndAbove) {
	enum LLVMDWARFSourceLanguage {
		C89 = 0,
		C = 1,
		Ada83 = 2,
		C_plus_plus = 3,
		Cobol74 = 4,
		Cobol85 = 5,
		Fortran77 = 6,
		Fortran90 = 7,
		Pascal83 = 8,
		Modula2 = 9,
		Java = 10,
		C99 = 11,
		Ada95 = 12,
		Fortran95 = 13,
		PLI = 14,
		ObjC = 15,
		ObjC_plus_plus = 16,
		UPC = 17,
		D = 18,
		Python = 19,
		OpenCL = 20,
		Go = 21,
		Modula3 = 22,
		Haskell = 23,
		C_plus_plus_03 = 24,
		C_plus_plus_11 = 25,
		OCaml = 26,
		Rust = 27,
		C11 = 28,
		Swift = 29,
		Julia = 30,
		Dylan = 31,
		C_plus_plus_14 = 32,
		Fortran03 = 33,
		Fortran08 = 34,
		RenderScript = 35,
		BLISS = 36,
		Kotlin = 37,
		Zig = 38,
		Crystal = 39,
		C_plus_plus_17 = 40,
		C_plus_plus_20 = 41,
		C17 = 42,
		Fortran18 = 43,
		Ada2005 = 44,
		Ada2012 = 45,
		HIP = 46,
		Assembly = 47,
		C_sharp = 48,
		Mojo = 49,
		GLSL = 50,
		GLSL_ES = 51,
		HLSL = 52,
		OpenCL_CPP = 53,
		CPP_for_OpenCL = 54,
		SYCL = 55,
		Ruby = 56,
		Move = 57,
		Hylo = 58,
		Metal = 59,
		Mips_Assembler = 60,
		GOOGLE_RenderScript = 61,
		BORLAND_Delphi = 62,
	}
} else version(LLVMVersion19AndAbove) {
	enum LLVMDWARFSourceLanguage {
		C89 = 0,
		C = 1,
		Ada83 = 2,
		C_plus_plus = 3,
		Cobol74 = 4,
		Cobol85 = 5,
		Fortran77 = 6,
		Fortran90 = 7,
		Pascal83 = 8,
		Modula2 = 9,
		Java = 10,
		C99 = 11,
		Ada95 = 12,
		Fortran95 = 13,
		PLI = 14,
		ObjC = 15,
		ObjC_plus_plus = 16,
		UPC = 17,
		D = 18,
		Python = 19,
		OpenCL = 20,
		Go = 21,
		Modula3 = 22,
		Haskell = 23,
		C_plus_plus_03 = 24,
		C_plus_plus_11 = 25,
		OCaml = 26,
		Rust = 27,
		C11 = 28,
		Swift = 29,
		Julia = 30,
		Dylan = 31,
		C_plus_plus_14 = 32,
		Fortran03 = 33,
		Fortran08 = 34,
		RenderScript = 35,
		BLISS = 36,
		Kotlin = 37,
		Zig = 38,
		Crystal = 39,
		C_plus_plus_17 = 40,
		C_plus_plus_20 = 41,
		C17 = 42,
		Fortran18 = 43,
		Ada2005 = 44,
		Ada2012 = 45,
		HIP = 46,
		Assembly = 47,
		C_sharp = 48,
		Mojo = 49,
		GLSL = 50,
		GLSL_ES = 51,
		HLSL = 52,
		OpenCL_CPP = 53,
		CPP_for_OpenCL = 54,
		SYCL = 55,
		Ruby = 56,
		Move = 57,
		Hylo = 58,
		Mips_Assembler = 59,
		GOOGLE_RenderScript = 60,
		BORLAND_Delphi = 61,
	}
} else version(LLVMVersion17AndAbove) {
	enum LLVMDWARFSourceLanguage {
		C89 = 0,
		C = 1,
		Ada83 = 2,
		C_plus_plus = 3,
		Cobol74 = 4,
		Cobol85 = 5,
		Fortran77 = 6,
		Fortran90 = 7,
		Pascal83 = 8,
		Modula2 = 9,
		Java = 10,
		C99 = 11,
		Ada95 = 12,
		Fortran95 = 13,
		PLI = 14,
		ObjC = 15,
		ObjC_plus_plus = 16,
		UPC = 17,
		D = 18,
		Python = 19,
		OpenCL = 20,
		Go = 21,
		Modula3 = 22,
		Haskell = 23,
		C_plus_plus_03 = 24,
		C_plus_plus_11 = 25,
		OCaml = 26,
		Rust = 27,
		C11 = 28,
		Swift = 29,
		Julia = 30,
		Dylan = 31,
		C_plus_plus_14 = 32,
		Fortran03 = 33,
		Fortran08 = 34,
		RenderScript = 35,
		BLISS = 36,
		Kotlin = 37,
		Zig = 38,
		Crystal = 39,
		C_plus_plus_17 = 40,
		C_plus_plus_20 = 41,
		C17 = 42,
		Fortran18 = 43,
		Ada2005 = 44,
		Ada2012 = 45,
		Mojo = 46,
		Mips_Assembler = 47,
		GOOGLE_RenderScript = 48,
		BORLAND_Delphi = 49,
	}
} else version(LLVMVersion16AndAbove) {
	enum LLVMDWARFSourceLanguage {
		C89 = 0,
		C = 1,
		Ada83 = 2,
		C_plus_plus = 3,
		Cobol74 = 4,
		Cobol85 = 5,
		Fortran77 = 6,
		Fortran90 = 7,
		Pascal83 = 8,
		Modula2 = 9,
		Java = 10,
		C99 = 11,
		Ada95 = 12,
		Fortran95 = 13,
		PLI = 14,
		ObjC = 15,
		ObjC_plus_plus = 16,
		UPC = 17,
		D = 18,
		Python = 19,
		OpenCL = 20,
		Go = 21,
		Modula3 = 22,
		Haskell = 23,
		C_plus_plus_03 = 24,
		C_plus_plus_11 = 25,
		OCaml = 26,
		Rust = 27,
		C11 = 28,
		Swift = 29,
		Julia = 30,
		Dylan = 31,
		C_plus_plus_14 = 32,
		Fortran03 = 33,
		Fortran08 = 34,
		RenderScript = 35,
		BLISS = 36,
		Kotlin = 37,
		Zig = 38,
		Crystal = 39,
		C_plus_plus_17 = 40,
		C_plus_plus_20 = 41,
		C17 = 42,
		Fortran18 = 43,
		Ada2005 = 44,
		Ada2012 = 45,
		Mips_Assembler = 46,
		GOOGLE_RenderScript = 47,
		BORLAND_Delphi = 48,
	}
} else {
	enum LLVMDWARFSourceLanguage {
		C89 = 0,
		C = 1,
		Ada83 = 2,
		C_plus_plus = 3,
		Cobol74 = 4,
		Cobol85 = 5,
		Fortran77 = 6,
		Fortran90 = 7,
		Pascal83 = 8,
		Modula2 = 9,
		Java = 10,
		C99 = 11,
		Ada95 = 12,
		Fortran95 = 13,
		PLI = 14,
		ObjC = 15,
		ObjC_plus_plus = 16,
		UPC = 17,
		D = 18,
		Python = 19,
		OpenCL = 20,
		Go = 21,
		Modula3 = 22,
		Haskell = 23,
		C_plus_plus_03 = 24,
		C_plus_plus_11 = 25,
		OCaml = 26,
		Rust = 27,
		C11 = 28,
		Swift = 29,
		Julia = 30,
		Dylan = 31,
		C_plus_plus_14 = 32,
		Fortran03 = 33,
		Fortran08 = 34,
		RenderScript = 35,
		BLISS = 36,
		Mips_Assembler = 37,
		GOOGLE_RenderScript = 38,
		BORLAND_Delphi = 39,
	}
}
LLVMDIBuilderRef LLVMCreateDIBuilder(LLVMModuleRef M);
LLVMDIBuilderRef LLVMCreateDIBuilderDisallowUnresolved(LLVMModuleRef M);
LLVMMetadataRef LLVMDIBuilderCreateArrayType(LLVMDIBuilderRef Builder, ulong Size, uint AlignInBits, LLVMMetadataRef Ty, LLVMMetadataRef* Subscripts, uint NumSubscripts);
LLVMMetadataRef LLVMDIBuilderCreateArtificialType(LLVMDIBuilderRef Builder, LLVMMetadataRef Type);
LLVMMetadataRef LLVMDIBuilderCreateAutoVariable(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNo, LLVMMetadataRef Ty, LLVMBool AlwaysPreserve, LLVMDIFlags Flags, uint AlignInBits);
LLVMMetadataRef LLVMDIBuilderCreateBasicType(LLVMDIBuilderRef Builder, const(char)* Name, size_t NameLen, ulong SizeInBits, LLVMDWARFTypeEncoding Encoding, LLVMDIFlags Flags);
LLVMMetadataRef LLVMDIBuilderCreateBitFieldMemberType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNumber, ulong SizeInBits, ulong OffsetInBits, ulong StorageOffsetInBits, LLVMDIFlags Flags, LLVMMetadataRef Type);
LLVMMetadataRef LLVMDIBuilderCreateClassType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNumber, ulong SizeInBits, uint AlignInBits, ulong OffsetInBits, LLVMDIFlags Flags, LLVMMetadataRef DerivedFrom, LLVMMetadataRef* Elements, uint NumElements, LLVMMetadataRef VTableHolder, LLVMMetadataRef TemplateParamsNode, const(char)* UniqueIdentifier, size_t UniqueIdentifierLen);
LLVMMetadataRef LLVMDIBuilderCreateDebugLocation(LLVMContextRef Ctx, uint Line, uint Column, LLVMMetadataRef Scope, LLVMMetadataRef InlinedAt);
LLVMMetadataRef LLVMDIBuilderCreateEnumerationType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNumber, ulong SizeInBits, uint AlignInBits, LLVMMetadataRef* Elements, uint NumElements, LLVMMetadataRef ClassTy);
LLVMMetadataRef LLVMDIBuilderCreateEnumerator(LLVMDIBuilderRef Builder, const(char)* Name, size_t NameLen, long Value, LLVMBool IsUnsigned);
LLVMMetadataRef LLVMDIBuilderCreateFile(LLVMDIBuilderRef Builder, const(char)* Filename, size_t FilenameLen, const(char)* Directory, size_t DirectoryLen);
LLVMMetadataRef LLVMDIBuilderCreateForwardDecl(LLVMDIBuilderRef Builder, uint Tag, const(char)* Name, size_t NameLen, LLVMMetadataRef Scope, LLVMMetadataRef File, uint Line, uint RuntimeLang, ulong SizeInBits, uint AlignInBits, const(char)* UniqueIdentifier, size_t UniqueIdentifierLen);
LLVMMetadataRef LLVMDIBuilderCreateFunction(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, const(char)* LinkageName, size_t LinkageNameLen, LLVMMetadataRef File, uint LineNo, LLVMMetadataRef Ty, LLVMBool IsLocalToUnit, LLVMBool IsDefinition, uint ScopeLine, LLVMDIFlags Flags, LLVMBool IsOptimized);
LLVMMetadataRef LLVMDIBuilderCreateGlobalVariableExpression(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, const(char)* Linkage, size_t LinkLen, LLVMMetadataRef File, uint LineNo, LLVMMetadataRef Ty, LLVMBool LocalToUnit, LLVMMetadataRef Expr, LLVMMetadataRef Decl, uint AlignInBits);
LLVMMetadataRef LLVMDIBuilderCreateImportedModuleFromNamespace(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef NS, LLVMMetadataRef File, uint Line);
LLVMMetadataRef LLVMDIBuilderCreateInheritance(LLVMDIBuilderRef Builder, LLVMMetadataRef Ty, LLVMMetadataRef BaseTy, ulong BaseOffset, uint VBPtrOffset, LLVMDIFlags Flags);
LLVMMetadataRef LLVMDIBuilderCreateLexicalBlock(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef File, uint Line, uint Column);
LLVMMetadataRef LLVMDIBuilderCreateLexicalBlockFile(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef File, uint Discriminator);
LLVMMetadataRef LLVMDIBuilderCreateMacro(LLVMDIBuilderRef Builder, LLVMMetadataRef ParentMacroFile, uint Line, LLVMDWARFMacinfoRecordType RecordType, const(char)* Name, size_t NameLen, const(char)* Value, size_t ValueLen);
LLVMMetadataRef LLVMDIBuilderCreateMemberPointerType(LLVMDIBuilderRef Builder, LLVMMetadataRef PointeeType, LLVMMetadataRef ClassType, ulong SizeInBits, uint AlignInBits, LLVMDIFlags Flags);
LLVMMetadataRef LLVMDIBuilderCreateMemberType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNo, ulong SizeInBits, uint AlignInBits, ulong OffsetInBits, LLVMDIFlags Flags, LLVMMetadataRef Ty);
LLVMMetadataRef LLVMDIBuilderCreateModule(LLVMDIBuilderRef Builder, LLVMMetadataRef ParentScope, const(char)* Name, size_t NameLen, const(char)* ConfigMacros, size_t ConfigMacrosLen, const(char)* IncludePath, size_t IncludePathLen, const(char)* APINotesFile, size_t APINotesFileLen);
LLVMMetadataRef LLVMDIBuilderCreateNameSpace(LLVMDIBuilderRef Builder, LLVMMetadataRef ParentScope, const(char)* Name, size_t NameLen, LLVMBool ExportSymbols);
LLVMMetadataRef LLVMDIBuilderCreateNullPtrType(LLVMDIBuilderRef Builder);
LLVMMetadataRef LLVMDIBuilderCreateObjCIVar(LLVMDIBuilderRef Builder, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNo, ulong SizeInBits, uint AlignInBits, ulong OffsetInBits, LLVMDIFlags Flags, LLVMMetadataRef Ty, LLVMMetadataRef PropertyNode);
LLVMMetadataRef LLVMDIBuilderCreateObjCProperty(LLVMDIBuilderRef Builder, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNo, const(char)* GetterName, size_t GetterNameLen, const(char)* SetterName, size_t SetterNameLen, uint PropertyAttributes, LLVMMetadataRef Ty);
LLVMMetadataRef LLVMDIBuilderCreateParameterVariable(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, uint ArgNo, LLVMMetadataRef File, uint LineNo, LLVMMetadataRef Ty, LLVMBool AlwaysPreserve, LLVMDIFlags Flags);
LLVMMetadataRef LLVMDIBuilderCreatePointerType(LLVMDIBuilderRef Builder, LLVMMetadataRef PointeeTy, ulong SizeInBits, uint AlignInBits, uint AddressSpace, const(char)* Name, size_t NameLen);
LLVMMetadataRef LLVMDIBuilderCreateQualifiedType(LLVMDIBuilderRef Builder, uint Tag, LLVMMetadataRef Type);
LLVMMetadataRef LLVMDIBuilderCreateReferenceType(LLVMDIBuilderRef Builder, uint Tag, LLVMMetadataRef Type);
LLVMMetadataRef LLVMDIBuilderCreateReplaceableCompositeType(LLVMDIBuilderRef Builder, uint Tag, const(char)* Name, size_t NameLen, LLVMMetadataRef Scope, LLVMMetadataRef File, uint Line, uint RuntimeLang, ulong SizeInBits, uint AlignInBits, LLVMDIFlags Flags, const(char)* UniqueIdentifier, size_t UniqueIdentifierLen);
LLVMMetadataRef LLVMDIBuilderCreateStaticMemberType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNumber, LLVMMetadataRef Type, LLVMDIFlags Flags, LLVMValueRef ConstantVal, uint AlignInBits);
LLVMMetadataRef LLVMDIBuilderCreateStructType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNumber, ulong SizeInBits, uint AlignInBits, LLVMDIFlags Flags, LLVMMetadataRef DerivedFrom, LLVMMetadataRef* Elements, uint NumElements, uint RunTimeLang, LLVMMetadataRef VTableHolder, const(char)* UniqueId, size_t UniqueIdLen);
LLVMMetadataRef LLVMDIBuilderCreateSubroutineType(LLVMDIBuilderRef Builder, LLVMMetadataRef File, LLVMMetadataRef* ParameterTypes, uint NumParameterTypes, LLVMDIFlags Flags);
LLVMMetadataRef LLVMDIBuilderCreateTempGlobalVariableFwdDecl(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, const(char)* Linkage, size_t LnkLen, LLVMMetadataRef File, uint LineNo, LLVMMetadataRef Ty, LLVMBool LocalToUnit, LLVMMetadataRef Decl, uint AlignInBits);
LLVMMetadataRef LLVMDIBuilderCreateTempMacroFile(LLVMDIBuilderRef Builder, LLVMMetadataRef ParentMacroFile, uint Line, LLVMMetadataRef File);
LLVMMetadataRef LLVMDIBuilderCreateTypedef(LLVMDIBuilderRef Builder, LLVMMetadataRef Type, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNo, LLVMMetadataRef Scope, uint AlignInBits);
LLVMMetadataRef LLVMDIBuilderCreateUnionType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNumber, ulong SizeInBits, uint AlignInBits, LLVMDIFlags Flags, LLVMMetadataRef* Elements, uint NumElements, uint RunTimeLang, const(char)* UniqueId, size_t UniqueIdLen);
LLVMMetadataRef LLVMDIBuilderCreateUnspecifiedType(LLVMDIBuilderRef Builder, const(char)* Name, size_t NameLen);
LLVMMetadataRef LLVMDIBuilderCreateVectorType(LLVMDIBuilderRef Builder, ulong Size, uint AlignInBits, LLVMMetadataRef Ty, LLVMMetadataRef* Subscripts, uint NumSubscripts);
void LLVMDIBuilderFinalize(LLVMDIBuilderRef Builder);
LLVMMetadataRef LLVMDIBuilderGetOrCreateArray(LLVMDIBuilderRef Builder, LLVMMetadataRef* Data, size_t NumElements);
LLVMMetadataRef LLVMDIBuilderGetOrCreateSubrange(LLVMDIBuilderRef Builder, long LowerBound, long Count);
LLVMMetadataRef LLVMDIBuilderGetOrCreateTypeArray(LLVMDIBuilderRef Builder, LLVMMetadataRef* Data, size_t NumElements);
const(char)* LLVMDIFileGetDirectory(LLVMMetadataRef File, uint* Len);
const(char)* LLVMDIFileGetFilename(LLVMMetadataRef File, uint* Len);
const(char)* LLVMDIFileGetSource(LLVMMetadataRef File, uint* Len);
LLVMMetadataRef LLVMDIGlobalVariableExpressionGetExpression(LLVMMetadataRef GVE);
LLVMMetadataRef LLVMDIGlobalVariableExpressionGetVariable(LLVMMetadataRef GVE);
uint LLVMDILocationGetColumn(LLVMMetadataRef Location);
LLVMMetadataRef LLVMDILocationGetInlinedAt(LLVMMetadataRef Location);
uint LLVMDILocationGetLine(LLVMMetadataRef Location);
LLVMMetadataRef LLVMDILocationGetScope(LLVMMetadataRef Location);
LLVMMetadataRef LLVMDIScopeGetFile(LLVMMetadataRef Scope);
uint LLVMDISubprogramGetLine(LLVMMetadataRef Subprogram);
uint LLVMDITypeGetAlignInBits(LLVMMetadataRef DType);
LLVMDIFlags LLVMDITypeGetFlags(LLVMMetadataRef DType);
uint LLVMDITypeGetLine(LLVMMetadataRef DType);
const(char)* LLVMDITypeGetName(LLVMMetadataRef DType, size_t* Length);
ulong LLVMDITypeGetOffsetInBits(LLVMMetadataRef DType);
ulong LLVMDITypeGetSizeInBits(LLVMMetadataRef DType);
LLVMMetadataRef LLVMDIVariableGetFile(LLVMMetadataRef Var);
uint LLVMDIVariableGetLine(LLVMMetadataRef Var);
LLVMMetadataRef LLVMDIVariableGetScope(LLVMMetadataRef Var);
uint LLVMDebugMetadataVersion();
void LLVMDisposeDIBuilder(LLVMDIBuilderRef Builder);
void LLVMDisposeTemporaryMDNode(LLVMMetadataRef TempNode);
LLVMMetadataKind LLVMGetMetadataKind(LLVMMetadataRef Metadata);
uint LLVMGetModuleDebugMetadataVersion(LLVMModuleRef Module);
LLVMMetadataRef LLVMGetSubprogram(LLVMValueRef Func);
LLVMMetadataRef LLVMInstructionGetDebugLoc(LLVMValueRef Inst);
void LLVMInstructionSetDebugLoc(LLVMValueRef Inst, LLVMMetadataRef Loc);
void LLVMMetadataReplaceAllUsesWith(LLVMMetadataRef TempTargetMetadata, LLVMMetadataRef Replacement);
void LLVMSetSubprogram(LLVMValueRef Func, LLVMMetadataRef SP);
LLVMBool LLVMStripModuleDebugInfo(LLVMModuleRef Module);
LLVMMetadataRef LLVMTemporaryMDNode(LLVMContextRef Ctx, LLVMMetadataRef* Data, size_t NumElements);
version(LLVMVersion11AndAbove) {
	LLVMMetadataRef LLVMDIBuilderCreateCompileUnit(LLVMDIBuilderRef Builder, LLVMDWARFSourceLanguage Lang, LLVMMetadataRef FileRef, const(char)* Producer, size_t ProducerLen, LLVMBool isOptimized, const(char)* Flags, size_t FlagsLen, uint RuntimeVer, const(char)* SplitName, size_t SplitNameLen, LLVMDWARFEmissionKind Kind, uint DWOId, LLVMBool SplitDebugInlining, LLVMBool DebugInfoForProfiling, const(char)* SysRoot, size_t SysRootLen, const(char)* SDK, size_t SDKLen);
} else {
	LLVMMetadataRef LLVMDIBuilderCreateCompileUnit(LLVMDIBuilderRef Builder, LLVMDWARFSourceLanguage Lang, LLVMMetadataRef FileRef, const(char)* Producer, size_t ProducerLen, LLVMBool isOptimized, const(char)* Flags, size_t FlagsLen, uint RuntimeVer, const(char)* SplitName, size_t SplitNameLen, LLVMDWARFEmissionKind Kind, uint DWOId, LLVMBool SplitDebugInlining, LLVMBool DebugInfoForProfiling);
}
version(LLVMVersion14AndAbove) {
	LLVMMetadataRef LLVMDIBuilderCreateConstantValueExpression(LLVMDIBuilderRef Builder, ulong Value);
	LLVMMetadataRef LLVMDIBuilderCreateExpression(LLVMDIBuilderRef Builder, ulong* Addr, size_t Length);
	LLVMMetadataRef LLVMDIBuilderCreateImportedDeclaration(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef Decl, LLVMMetadataRef File, uint Line, const(char)* Name, size_t NameLen, LLVMMetadataRef* Elements, uint NumElements);
	LLVMMetadataRef LLVMDIBuilderCreateImportedModuleFromAlias(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef ImportedEntity, LLVMMetadataRef File, uint Line, LLVMMetadataRef* Elements, uint NumElements);
	LLVMMetadataRef LLVMDIBuilderCreateImportedModuleFromModule(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef M, LLVMMetadataRef File, uint Line, LLVMMetadataRef* Elements, uint NumElements);
} else {
	LLVMMetadataRef LLVMDIBuilderCreateConstantValueExpression(LLVMDIBuilderRef Builder, long Value);
	LLVMMetadataRef LLVMDIBuilderCreateExpression(LLVMDIBuilderRef Builder, long* Addr, size_t Length);
	LLVMMetadataRef LLVMDIBuilderCreateImportedDeclaration(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef Decl, LLVMMetadataRef File, uint Line, const(char)* Name, size_t NameLen);
	LLVMMetadataRef LLVMDIBuilderCreateImportedModuleFromAlias(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef ImportedEntity, LLVMMetadataRef File, uint Line);
	LLVMMetadataRef LLVMDIBuilderCreateImportedModuleFromModule(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, LLVMMetadataRef M, LLVMMetadataRef File, uint Line);
}
version(LLVMVersion19AndAbove) {
	// Removed
} else {
	LLVMValueRef LLVMDIBuilderInsertDbgValueAtEnd(LLVMDIBuilderRef Builder, LLVMValueRef Val, LLVMMetadataRef VarInfo, LLVMMetadataRef Expr, LLVMMetadataRef DebugLoc, LLVMBasicBlockRef Block);
	LLVMValueRef LLVMDIBuilderInsertDbgValueBefore(LLVMDIBuilderRef Builder, LLVMValueRef Val, LLVMMetadataRef VarInfo, LLVMMetadataRef Expr, LLVMMetadataRef DebugLoc, LLVMValueRef Instr);
	LLVMValueRef LLVMDIBuilderInsertDeclareAtEnd(LLVMDIBuilderRef Builder, LLVMValueRef Storage, LLVMMetadataRef VarInfo, LLVMMetadataRef Expr, LLVMMetadataRef DebugLoc, LLVMBasicBlockRef Block);
	LLVMValueRef LLVMDIBuilderInsertDeclareBefore(LLVMDIBuilderRef Builder, LLVMValueRef Storage, LLVMMetadataRef VarInfo, LLVMMetadataRef Expr, LLVMMetadataRef DebugLoc, LLVMValueRef Instr);
}
version(LLVMVersion20AndAbove) {
	LLVMMetadataRef LLVMDIBuilderCreateObjectPointerType(LLVMDIBuilderRef Builder, LLVMMetadataRef Type, LLVMBool Implicit);
} else {
	LLVMMetadataRef LLVMDIBuilderCreateObjectPointerType(LLVMDIBuilderRef Builder, LLVMMetadataRef Type);
}
version(LLVMVersion14AndAbove) {
	void LLVMDIBuilderFinalizeSubprogram(LLVMDIBuilderRef Builder, LLVMMetadataRef Subprogram);
}
version(LLVMVersion17AndAbove) {
	ushort LLVMGetDINodeTag(LLVMMetadataRef MD);
}
version(LLVMVersion19AndAbove) {
	LLVMDbgRecordRef LLVMDIBuilderInsertDbgValueRecordAtEnd(LLVMDIBuilderRef Builder, LLVMValueRef Val, LLVMMetadataRef VarInfo, LLVMMetadataRef Expr, LLVMMetadataRef DebugLoc, LLVMBasicBlockRef Block);
	LLVMDbgRecordRef LLVMDIBuilderInsertDbgValueRecordBefore(LLVMDIBuilderRef Builder, LLVMValueRef Val, LLVMMetadataRef VarInfo, LLVMMetadataRef Expr, LLVMMetadataRef DebugLoc, LLVMValueRef Instr);
	LLVMDbgRecordRef LLVMDIBuilderInsertDeclareRecordAtEnd(LLVMDIBuilderRef Builder, LLVMValueRef Storage, LLVMMetadataRef VarInfo, LLVMMetadataRef Expr, LLVMMetadataRef DebugLoc, LLVMBasicBlockRef Block);
	LLVMDbgRecordRef LLVMDIBuilderInsertDeclareRecordBefore(LLVMDIBuilderRef Builder, LLVMValueRef Storage, LLVMMetadataRef VarInfo, LLVMMetadataRef Expr, LLVMMetadataRef DebugLoc, LLVMValueRef Instr);
}
version(LLVMVersion20AndAbove) {
	LLVMMetadataRef LLVMDIBuilderCreateLabel(LLVMDIBuilderRef Builder, LLVMMetadataRef Context, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNo, LLVMBool AlwaysPreserve);
	LLVMDbgRecordRef LLVMDIBuilderInsertLabelAtEnd(LLVMDIBuilderRef Builder, LLVMMetadataRef LabelInfo, LLVMMetadataRef Location, LLVMBasicBlockRef InsertAtEnd);
	LLVMDbgRecordRef LLVMDIBuilderInsertLabelBefore(LLVMDIBuilderRef Builder, LLVMMetadataRef LabelInfo, LLVMMetadataRef Location, LLVMValueRef InsertBefore);
}
version(LLVMVersion21AndAbove) {
	LLVMMetadataRef LLVMDIBuilderCreateDynamicArrayType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, uint LineNo, LLVMMetadataRef File, ulong Size, uint AlignInBits, LLVMMetadataRef Ty, LLVMMetadataRef* Subscripts, uint NumSubscripts, LLVMMetadataRef DataLocation, LLVMMetadataRef Associated, LLVMMetadataRef Allocated, LLVMMetadataRef Rank, LLVMMetadataRef BitStride);
	LLVMMetadataRef LLVMDIBuilderCreateEnumeratorOfArbitraryPrecision(LLVMDIBuilderRef Builder, const(char)* Name, size_t NameLen, ulong SizeInBits, const(ulong)* Words, LLVMBool IsUnsigned);
	LLVMMetadataRef LLVMDIBuilderCreateSetType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, LLVMMetadataRef File, uint LineNumber, ulong SizeInBits, uint AlignInBits, LLVMMetadataRef BaseTy);
	LLVMMetadataRef LLVMDIBuilderCreateSubrangeType(LLVMDIBuilderRef Builder, LLVMMetadataRef Scope, const(char)* Name, size_t NameLen, uint LineNo, LLVMMetadataRef File, ulong SizeInBits, uint AlignInBits, LLVMDIFlags Flags, LLVMMetadataRef BaseTy, LLVMMetadataRef LowerBound, LLVMMetadataRef UpperBound, LLVMMetadataRef Stride, LLVMMetadataRef Bias);
	void LLVMDISubprogramReplaceType(LLVMMetadataRef Subprogram, LLVMMetadataRef SubroutineType);
	void LLVMReplaceArrays(LLVMDIBuilderRef Builder, LLVMMetadataRef* T, LLVMMetadataRef* Elements, uint NumElements);
}
