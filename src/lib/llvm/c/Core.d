/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.Core;

public import lib.llvm.c.Types;


enum LLVMAttributeIndex : uint {
	Return = 0U,
	Function = cast(uint)-1,
}


alias LLVMDiagnosticHandler = extern(C) void function(LLVMDiagnosticInfoRef, void *);
alias LLVMYieldCallback = extern(C) void function(LLVMContextRef, void *);


extern(C):

//#--- Auto generated below ---#
enum LLVMAtomicOrdering {
	NotAtomic = 0,
	Unordered = 1,
	Monotonic = 2,
	Acquire = 4,
	Release = 5,
	AcquireRelease = 6,
	SequentiallyConsistent = 7,
}
enum LLVMDLLStorageClass {
	Default = 0,
	DLLImport = 1,
	DLLExport = 2,
}
enum LLVMDiagnosticSeverity {
	Error = 0,
	Warning = 1,
	Remark = 2,
	Note = 3,
}
enum LLVMInlineAsmDialect {
	ATT = 0,
	Intel = 1,
}
enum LLVMIntPredicate {
	EQ = 32,
	NE = 33,
	UGT = 34,
	UGE = 35,
	ULT = 36,
	ULE = 37,
	SGT = 38,
	SGE = 39,
	SLT = 40,
	SLE = 41,
}
enum LLVMLinkage {
	External = 0,
	AvailableExternally = 1,
	LinkOnceAny = 2,
	LinkOnceODR = 3,
	LinkOnceODRAutoHide = 4,
	WeakAny = 5,
	WeakODR = 6,
	Appending = 7,
	Internal = 8,
	Private = 9,
	DLLImport = 10,
	DLLExport = 11,
	ExternalWeak = 12,
	Ghost = 13,
	Common = 14,
	LinkerPrivate = 15,
	LinkerPrivateWeak = 16,
}
enum LLVMModuleFlagBehavior {
	Error = 0,
	Warning = 1,
	Require = 2,
	Override = 3,
	Append = 4,
	AppendUnique = 5,
}
enum LLVMOpcode {
	Ret = 1,
	Br = 2,
	Switch = 3,
	IndirectBr = 4,
	Invoke = 5,
	Unreachable = 7,
	CallBr = 67,
	FNeg = 66,
	Add = 8,
	FAdd = 9,
	Sub = 10,
	FSub = 11,
	Mul = 12,
	FMul = 13,
	UDiv = 14,
	SDiv = 15,
	FDiv = 16,
	URem = 17,
	SRem = 18,
	FRem = 19,
	Shl = 20,
	LShr = 21,
	AShr = 22,
	And = 23,
	Or = 24,
	Xor = 25,
	Alloca = 26,
	Load = 27,
	Store = 28,
	GetElementPtr = 29,
	Trunc = 30,
	ZExt = 31,
	SExt = 32,
	FPToUI = 33,
	FPToSI = 34,
	UIToFP = 35,
	SIToFP = 36,
	FPTrunc = 37,
	FPExt = 38,
	PtrToInt = 39,
	IntToPtr = 40,
	BitCast = 41,
	AddrSpaceCast = 60,
	ICmp = 42,
	FCmp = 43,
	PHI = 44,
	Call = 45,
	Select = 46,
	UserOp1 = 47,
	UserOp2 = 48,
	VAArg = 49,
	ExtractElement = 50,
	InsertElement = 51,
	ShuffleVector = 52,
	ExtractValue = 53,
	InsertValue = 54,
	Freeze = 68,
	Fence = 55,
	AtomicCmpXchg = 56,
	AtomicRMW = 57,
	Resume = 58,
	LandingPad = 59,
	CleanupRet = 61,
	CatchRet = 62,
	CatchPad = 63,
	CleanupPad = 64,
	CatchSwitch = 65,
}
enum LLVMRealPredicate {
	PredicateFalse = 0,
	OEQ = 1,
	OGT = 2,
	OGE = 3,
	OLT = 4,
	OLE = 5,
	ONE = 6,
	ORD = 7,
	UNO = 8,
	UEQ = 9,
	UGT = 10,
	UGE = 11,
	ULT = 12,
	ULE = 13,
	UNE = 14,
	PredicateTrue = 15,
}
enum LLVMThreadLocalMode {
	Not = 0,
	GeneralDynamicTLSModel = 1,
	LocalDynamicTLSModel = 2,
	InitialExecTLSModel = 3,
	LocalExecTLSModel = 4,
}
enum LLVMUnnamedAddr {
	NoUnnamed = 0,
	LocalUnnamed = 1,
	GlobalUnnamed = 2,
}
enum LLVMVisibility {
	Default = 0,
	Hidden = 1,
	Protected = 2,
}
version(LLVMVersion20AndAbove) {
	enum LLVMTypeKind {
		Void = 0,
		Half = 1,
		Float = 2,
		Double = 3,
		X86_FP80 = 4,
		FP128 = 5,
		PPC_FP128 = 6,
		Label = 7,
		Integer = 8,
		Function = 9,
		Struct = 10,
		Array = 11,
		Pointer = 12,
		Vector = 13,
		Metadata = 14,
		Token = 16,
		ScalableVector = 17,
		BFloat = 18,
		X86_AMX = 19,
		TargetExt = 20,
	}
} else version(LLVMVersion16AndAbove) {
	enum LLVMTypeKind {
		Void = 0,
		Half = 1,
		Float = 2,
		Double = 3,
		X86_FP80 = 4,
		FP128 = 5,
		PPC_FP128 = 6,
		Label = 7,
		Integer = 8,
		Function = 9,
		Struct = 10,
		Array = 11,
		Pointer = 12,
		Vector = 13,
		Metadata = 14,
		X86_MMX = 15,
		Token = 16,
		ScalableVector = 17,
		BFloat = 18,
		X86_AMX = 19,
		TargetExt = 20,
	}
} else version(LLVMVersion12AndAbove) {
	enum LLVMTypeKind {
		Void = 0,
		Half = 1,
		Float = 2,
		Double = 3,
		X86_FP80 = 4,
		FP128 = 5,
		PPC_FP128 = 6,
		Label = 7,
		Integer = 8,
		Function = 9,
		Struct = 10,
		Array = 11,
		Pointer = 12,
		Vector = 13,
		Metadata = 14,
		X86_MMX = 15,
		Token = 16,
		ScalableVector = 17,
		BFloat = 18,
		X86_AMX = 19,
	}
} else version(LLVMVersion11AndAbove) {
	enum LLVMTypeKind {
		Void = 0,
		Half = 1,
		Float = 2,
		Double = 3,
		X86_FP80 = 4,
		FP128 = 5,
		PPC_FP128 = 6,
		Label = 7,
		Integer = 8,
		Function = 9,
		Struct = 10,
		Array = 11,
		Pointer = 12,
		Vector = 13,
		Metadata = 14,
		X86_MMX = 15,
		Token = 16,
		ScalableVector = 17,
		BFloat = 18,
	}
} else {
	enum LLVMTypeKind {
		Void = 0,
		Half = 1,
		Float = 2,
		Double = 3,
		X86_FP80 = 4,
		FP128 = 5,
		PPC_FP128 = 6,
		Label = 7,
		Integer = 8,
		Function = 9,
		Struct = 10,
		Array = 11,
		Pointer = 12,
		Vector = 13,
		Metadata = 14,
		X86_MMX = 15,
		Token = 16,
	}
}
version(LLVMVersion19AndAbove) {
	enum LLVMValueKind {
		Argument = 0,
		BasicBlock = 1,
		MemoryUse = 2,
		MemoryDef = 3,
		MemoryPhi = 4,
		Function = 5,
		GlobalAlias = 6,
		GlobalIFunc = 7,
		GlobalVariable = 8,
		BlockAddress = 9,
		ConstantExpr = 10,
		ConstantArray = 11,
		ConstantStruct = 12,
		ConstantVector = 13,
		UndefValue = 14,
		ConstantAggregateZero = 15,
		ConstantDataArray = 16,
		ConstantDataVector = 17,
		ConstantInt = 18,
		ConstantFP = 19,
		ConstantPointerNull = 20,
		ConstantTokenNone = 21,
		MetadataAsValue = 22,
		InlineAsm = 23,
		Instruction = 24,
		PoisonValue = 25,
		ConstantTargetNone = 26,
		ConstantPtrAuth = 27,
	}
} else version(LLVMVersion16AndAbove) {
	enum LLVMValueKind {
		Argument = 0,
		BasicBlock = 1,
		MemoryUse = 2,
		MemoryDef = 3,
		MemoryPhi = 4,
		Function = 5,
		GlobalAlias = 6,
		GlobalIFunc = 7,
		GlobalVariable = 8,
		BlockAddress = 9,
		ConstantExpr = 10,
		ConstantArray = 11,
		ConstantStruct = 12,
		ConstantVector = 13,
		UndefValue = 14,
		ConstantAggregateZero = 15,
		ConstantDataArray = 16,
		ConstantDataVector = 17,
		ConstantInt = 18,
		ConstantFP = 19,
		ConstantPointerNull = 20,
		ConstantTokenNone = 21,
		MetadataAsValue = 22,
		InlineAsm = 23,
		Instruction = 24,
		PoisonValue = 25,
		ConstantTargetNone = 26,
	}
} else version(LLVMVersion12AndAbove) {
	enum LLVMValueKind {
		Argument = 0,
		BasicBlock = 1,
		MemoryUse = 2,
		MemoryDef = 3,
		MemoryPhi = 4,
		Function = 5,
		GlobalAlias = 6,
		GlobalIFunc = 7,
		GlobalVariable = 8,
		BlockAddress = 9,
		ConstantExpr = 10,
		ConstantArray = 11,
		ConstantStruct = 12,
		ConstantVector = 13,
		UndefValue = 14,
		ConstantAggregateZero = 15,
		ConstantDataArray = 16,
		ConstantDataVector = 17,
		ConstantInt = 18,
		ConstantFP = 19,
		ConstantPointerNull = 20,
		ConstantTokenNone = 21,
		MetadataAsValue = 22,
		InlineAsm = 23,
		Instruction = 24,
		PoisonValue = 25,
	}
} else {
	enum LLVMValueKind {
		Argument = 0,
		BasicBlock = 1,
		MemoryUse = 2,
		MemoryDef = 3,
		MemoryPhi = 4,
		Function = 5,
		GlobalAlias = 6,
		GlobalIFunc = 7,
		GlobalVariable = 8,
		BlockAddress = 9,
		ConstantExpr = 10,
		ConstantArray = 11,
		ConstantStruct = 12,
		ConstantVector = 13,
		UndefValue = 14,
		ConstantAggregateZero = 15,
		ConstantDataArray = 16,
		ConstantDataVector = 17,
		ConstantInt = 18,
		ConstantFP = 19,
		ConstantPointerNull = 20,
		ConstantTokenNone = 21,
		MetadataAsValue = 22,
		InlineAsm = 23,
		Instruction = 24,
	}
}
version(LLVMVersion21AndAbove) {
	enum LLVMAtomicRMWBinOp {
		Xchg = 0,
		Add = 1,
		Sub = 2,
		And = 3,
		Nand = 4,
		Or = 5,
		Xor = 6,
		Max = 7,
		Min = 8,
		UMax = 9,
		UMin = 10,
		FAdd = 11,
		FSub = 12,
		FMax = 13,
		FMin = 14,
		UIncWrap = 15,
		UDecWrap = 16,
		USubCond = 17,
		USubSat = 18,
		FMaximum = 19,
		FMinimum = 20,
	}
} else version(LLVMVersion20AndAbove) {
	enum LLVMAtomicRMWBinOp {
		Xchg = 0,
		Add = 1,
		Sub = 2,
		And = 3,
		Nand = 4,
		Or = 5,
		Xor = 6,
		Max = 7,
		Min = 8,
		UMax = 9,
		UMin = 10,
		FAdd = 11,
		FSub = 12,
		FMax = 13,
		FMin = 14,
		UIncWrap = 15,
		UDecWrap = 16,
		USubCond = 17,
		USubSat = 18,
	}
} else version(LLVMVersion19AndAbove) {
	enum LLVMAtomicRMWBinOp {
		Xchg = 0,
		Add = 1,
		Sub = 2,
		And = 3,
		Nand = 4,
		Or = 5,
		Xor = 6,
		Max = 7,
		Min = 8,
		UMax = 9,
		UMin = 10,
		FAdd = 11,
		FSub = 12,
		FMax = 13,
		FMin = 14,
		UIncWrap = 15,
		UDecWrap = 16,
	}
} else version(LLVMVersion15AndAbove) {
	enum LLVMAtomicRMWBinOp {
		Xchg = 0,
		Add = 1,
		Sub = 2,
		And = 3,
		Nand = 4,
		Or = 5,
		Xor = 6,
		Max = 7,
		Min = 8,
		UMax = 9,
		UMin = 10,
		FAdd = 11,
		FSub = 12,
		FMax = 13,
		FMin = 14,
	}
} else {
	enum LLVMAtomicRMWBinOp {
		Xchg = 0,
		Add = 1,
		Sub = 2,
		And = 3,
		Nand = 4,
		Or = 5,
		Xor = 6,
		Max = 7,
		Min = 8,
		UMax = 9,
		UMin = 10,
		FAdd = 11,
		FSub = 12,
	}
}
version(LLVMVersion18AndAbove) {
	enum LLVMCallConv {
		C = 0,
		Fast = 8,
		Cold = 9,
		GHC = 10,
		HiPE = 11,
		AnyReg = 13,
		PreserveMost = 14,
		PreserveAll = 15,
		Swift = 16,
		CXXFASTTLS = 17,
		X86Stdcall = 64,
		X86Fastcall = 65,
		ARMAPCS = 66,
		ARMAAPCS = 67,
		ARMAAPCSVFP = 68,
		MSP430INTR = 69,
		X86ThisCall = 70,
		PTXKernel = 71,
		PTXDevice = 72,
		SPIRFUNC = 75,
		SPIRKERNEL = 76,
		IntelOCLBI = 77,
		X8664SysV = 78,
		Win64 = 79,
		X86VectorCall = 80,
		HHVM = 81,
		HHVMC = 82,
		X86INTR = 83,
		AVRINTR = 84,
		AVRSIGNAL = 85,
		AVRBUILTIN = 86,
		AMDGPUVS = 87,
		AMDGPUGS = 88,
		AMDGPUPS = 89,
		AMDGPUCS = 90,
		AMDGPUKERNEL = 91,
		X86RegCall = 92,
		AMDGPUHS = 93,
		MSP430BUILTIN = 94,
		AMDGPULS = 95,
		AMDGPUES = 96,
	}
} else {
	enum LLVMCallConv {
		C = 0,
		Fast = 8,
		Cold = 9,
		GHC = 10,
		HiPE = 11,
		WebKitJS = 12,
		AnyReg = 13,
		PreserveMost = 14,
		PreserveAll = 15,
		Swift = 16,
		CXXFASTTLS = 17,
		X86Stdcall = 64,
		X86Fastcall = 65,
		ARMAPCS = 66,
		ARMAAPCS = 67,
		ARMAAPCSVFP = 68,
		MSP430INTR = 69,
		X86ThisCall = 70,
		PTXKernel = 71,
		PTXDevice = 72,
		SPIRFUNC = 75,
		SPIRKERNEL = 76,
		IntelOCLBI = 77,
		X8664SysV = 78,
		Win64 = 79,
		X86VectorCall = 80,
		HHVM = 81,
		HHVMC = 82,
		X86INTR = 83,
		AVRINTR = 84,
		AVRSIGNAL = 85,
		AVRBUILTIN = 86,
		AMDGPUVS = 87,
		AMDGPUGS = 88,
		AMDGPUPS = 89,
		AMDGPUCS = 90,
		AMDGPUKERNEL = 91,
		X86RegCall = 92,
		AMDGPUHS = 93,
		MSP430BUILTIN = 94,
		AMDGPULS = 95,
		AMDGPUES = 96,
	}
}
version(LLVMVersion21AndAbove) {
	// Removed
} else {
	enum LLVMLandingPadClauseTy {
		Catch = 0,
		Filter = 1,
	}
}
version(LLVMVersion18AndAbove) {
	enum LLVMTailCallKind {
		None = 0,
		Tail = 1,
		MustTail = 2,
		NoTail = 3,
	}
}
void LLVMAddAttributeAtIndex(LLVMValueRef F, LLVMAttributeIndex Idx, LLVMAttributeRef A);
void LLVMAddCallSiteAttribute(LLVMValueRef C, LLVMAttributeIndex Idx, LLVMAttributeRef A);
void LLVMAddCase(LLVMValueRef Switch, LLVMValueRef OnVal, LLVMBasicBlockRef Dest);
void LLVMAddClause(LLVMValueRef LandingPad, LLVMValueRef ClauseVal);
void LLVMAddDestination(LLVMValueRef IndirectBr, LLVMBasicBlockRef Dest);
LLVMValueRef LLVMAddFunction(LLVMModuleRef M, const(char)* Name, LLVMTypeRef FunctionTy);
LLVMValueRef LLVMAddGlobal(LLVMModuleRef M, LLVMTypeRef Ty, const(char)* Name);
LLVMValueRef LLVMAddGlobalIFunc(LLVMModuleRef M, const(char)* Name, size_t NameLen, LLVMTypeRef Ty, uint AddrSpace, LLVMValueRef Resolver);
LLVMValueRef LLVMAddGlobalInAddressSpace(LLVMModuleRef M, LLVMTypeRef Ty, const(char)* Name, uint AddressSpace);
void LLVMAddHandler(LLVMValueRef CatchSwitch, LLVMBasicBlockRef Dest);
void LLVMAddIncoming(LLVMValueRef PhiNode, LLVMValueRef* IncomingValues, LLVMBasicBlockRef* IncomingBlocks, uint Count);
void LLVMAddModuleFlag(LLVMModuleRef M, LLVMModuleFlagBehavior Behavior, const(char)* Key, size_t KeyLen, LLVMMetadataRef Val);
void LLVMAddNamedMetadataOperand(LLVMModuleRef M, const(char)* Name, LLVMValueRef Val);
void LLVMAddTargetDependentFunctionAttr(LLVMValueRef Fn, const(char)* A, const(char)* V);
LLVMValueRef LLVMAliasGetAliasee(LLVMValueRef Alias);
void LLVMAliasSetAliasee(LLVMValueRef Alias, LLVMValueRef Aliasee);
LLVMValueRef LLVMAlignOf(LLVMTypeRef Ty);
LLVMBasicBlockRef LLVMAppendBasicBlock(LLVMValueRef Fn, const(char)* Name);
LLVMBasicBlockRef LLVMAppendBasicBlockInContext(LLVMContextRef C, LLVMValueRef Fn, const(char)* Name);
void LLVMAppendExistingBasicBlock(LLVMValueRef Fn, LLVMBasicBlockRef BB);
void LLVMAppendModuleInlineAsm(LLVMModuleRef M, const(char)* Asm, size_t Len);
LLVMTypeRef LLVMArrayType(LLVMTypeRef ElementType, uint ElementCount);
LLVMValueRef LLVMBasicBlockAsValue(LLVMBasicBlockRef BB);
LLVMValueRef LLVMBlockAddress(LLVMValueRef F, LLVMBasicBlockRef BB);
LLVMValueRef LLVMBuildAShr(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildAddrSpaceCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildAggregateRet(LLVMBuilderRef, LLVMValueRef* RetVals, uint N);
LLVMValueRef LLVMBuildAlloca(LLVMBuilderRef, LLVMTypeRef Ty, const(char)* Name);
LLVMValueRef LLVMBuildAnd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildArrayAlloca(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Val, const(char)* Name);
LLVMValueRef LLVMBuildArrayMalloc(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Val, const(char)* Name);
LLVMValueRef LLVMBuildAtomicCmpXchg(LLVMBuilderRef B, LLVMValueRef Ptr, LLVMValueRef Cmp, LLVMValueRef New, LLVMAtomicOrdering SuccessOrdering, LLVMAtomicOrdering FailureOrdering, LLVMBool SingleThread);
LLVMValueRef LLVMBuildAtomicRMW(LLVMBuilderRef B, LLVMAtomicRMWBinOp op, LLVMValueRef PTR, LLVMValueRef Val, LLVMAtomicOrdering ordering, LLVMBool singleThread);
LLVMValueRef LLVMBuildBinOp(LLVMBuilderRef B, LLVMOpcode Op, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildBitCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildBr(LLVMBuilderRef, LLVMBasicBlockRef Dest);
LLVMValueRef LLVMBuildCall2(LLVMBuilderRef, LLVMTypeRef, LLVMValueRef Fn, LLVMValueRef* Args, uint NumArgs, const(char)* Name);
LLVMValueRef LLVMBuildCast(LLVMBuilderRef B, LLVMOpcode Op, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildCatchPad(LLVMBuilderRef B, LLVMValueRef ParentPad, LLVMValueRef* Args, uint NumArgs, const(char)* Name);
LLVMValueRef LLVMBuildCatchRet(LLVMBuilderRef B, LLVMValueRef CatchPad, LLVMBasicBlockRef BB);
LLVMValueRef LLVMBuildCatchSwitch(LLVMBuilderRef B, LLVMValueRef ParentPad, LLVMBasicBlockRef UnwindBB, uint NumHandlers, const(char)* Name);
LLVMValueRef LLVMBuildCleanupPad(LLVMBuilderRef B, LLVMValueRef ParentPad, LLVMValueRef* Args, uint NumArgs, const(char)* Name);
LLVMValueRef LLVMBuildCleanupRet(LLVMBuilderRef B, LLVMValueRef CatchPad, LLVMBasicBlockRef BB);
LLVMValueRef LLVMBuildCondBr(LLVMBuilderRef, LLVMValueRef If, LLVMBasicBlockRef Then, LLVMBasicBlockRef Else);
LLVMValueRef LLVMBuildExactSDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildExactUDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildExtractElement(LLVMBuilderRef, LLVMValueRef VecVal, LLVMValueRef Index, const(char)* Name);
LLVMValueRef LLVMBuildExtractValue(LLVMBuilderRef, LLVMValueRef AggVal, uint Index, const(char)* Name);
LLVMValueRef LLVMBuildFAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildFCmp(LLVMBuilderRef, LLVMRealPredicate Op, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildFDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildFMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildFNeg(LLVMBuilderRef, LLVMValueRef V, const(char)* Name);
LLVMValueRef LLVMBuildFPCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildFPExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildFPToSI(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildFPToUI(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildFPTrunc(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildFRem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildFSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildFence(LLVMBuilderRef B, LLVMAtomicOrdering ordering, LLVMBool singleThread, const(char)* Name);
LLVMValueRef LLVMBuildFree(LLVMBuilderRef, LLVMValueRef PointerVal);
LLVMValueRef LLVMBuildFreeze(LLVMBuilderRef, LLVMValueRef Val, const(char)* Name);
LLVMValueRef LLVMBuildGEP2(LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Pointer, LLVMValueRef* Indices, uint NumIndices, const(char)* Name);
LLVMValueRef LLVMBuildGlobalString(LLVMBuilderRef B, const(char)* Str, const(char)* Name);
LLVMValueRef LLVMBuildGlobalStringPtr(LLVMBuilderRef B, const(char)* Str, const(char)* Name);
LLVMValueRef LLVMBuildICmp(LLVMBuilderRef, LLVMIntPredicate Op, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildInBoundsGEP2(LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Pointer, LLVMValueRef* Indices, uint NumIndices, const(char)* Name);
LLVMValueRef LLVMBuildIndirectBr(LLVMBuilderRef B, LLVMValueRef Addr, uint NumDests);
LLVMValueRef LLVMBuildInsertElement(LLVMBuilderRef, LLVMValueRef VecVal, LLVMValueRef EltVal, LLVMValueRef Index, const(char)* Name);
LLVMValueRef LLVMBuildInsertValue(LLVMBuilderRef, LLVMValueRef AggVal, LLVMValueRef EltVal, uint Index, const(char)* Name);
LLVMValueRef LLVMBuildIntCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildIntCast2(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, LLVMBool IsSigned, const(char)* Name);
LLVMValueRef LLVMBuildIntToPtr(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildInvoke2(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Fn, LLVMValueRef* Args, uint NumArgs, LLVMBasicBlockRef Then, LLVMBasicBlockRef Catch, const(char)* Name);
LLVMValueRef LLVMBuildIsNotNull(LLVMBuilderRef, LLVMValueRef Val, const(char)* Name);
LLVMValueRef LLVMBuildIsNull(LLVMBuilderRef, LLVMValueRef Val, const(char)* Name);
LLVMValueRef LLVMBuildLShr(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildLandingPad(LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef PersFn, uint NumClauses, const(char)* Name);
LLVMValueRef LLVMBuildLoad2(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef PointerVal, const(char)* Name);
LLVMValueRef LLVMBuildMalloc(LLVMBuilderRef, LLVMTypeRef Ty, const(char)* Name);
LLVMValueRef LLVMBuildMemCpy(LLVMBuilderRef B, LLVMValueRef Dst, uint DstAlign, LLVMValueRef Src, uint SrcAlign, LLVMValueRef Size);
LLVMValueRef LLVMBuildMemMove(LLVMBuilderRef B, LLVMValueRef Dst, uint DstAlign, LLVMValueRef Src, uint SrcAlign, LLVMValueRef Size);
LLVMValueRef LLVMBuildMemSet(LLVMBuilderRef B, LLVMValueRef Ptr, LLVMValueRef Val, LLVMValueRef Len, uint Align);
LLVMValueRef LLVMBuildMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildNSWAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildNSWMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildNSWNeg(LLVMBuilderRef B, LLVMValueRef V, const(char)* Name);
LLVMValueRef LLVMBuildNSWSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildNUWAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildNUWMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildNUWNeg(LLVMBuilderRef B, LLVMValueRef V, const(char)* Name);
LLVMValueRef LLVMBuildNUWSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildNeg(LLVMBuilderRef, LLVMValueRef V, const(char)* Name);
LLVMValueRef LLVMBuildNot(LLVMBuilderRef, LLVMValueRef V, const(char)* Name);
LLVMValueRef LLVMBuildOr(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildPhi(LLVMBuilderRef, LLVMTypeRef Ty, const(char)* Name);
LLVMValueRef LLVMBuildPointerCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildPtrToInt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildResume(LLVMBuilderRef B, LLVMValueRef Exn);
LLVMValueRef LLVMBuildRet(LLVMBuilderRef, LLVMValueRef V);
LLVMValueRef LLVMBuildRetVoid(LLVMBuilderRef);
LLVMValueRef LLVMBuildSDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildSExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildSExtOrBitCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildSIToFP(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildSRem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildSelect(LLVMBuilderRef, LLVMValueRef If, LLVMValueRef Then, LLVMValueRef Else, const(char)* Name);
LLVMValueRef LLVMBuildShl(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildShuffleVector(LLVMBuilderRef, LLVMValueRef V1, LLVMValueRef V2, LLVMValueRef Mask, const(char)* Name);
LLVMValueRef LLVMBuildStore(LLVMBuilderRef, LLVMValueRef Val, LLVMValueRef Ptr);
LLVMValueRef LLVMBuildStructGEP2(LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Pointer, uint Idx, const(char)* Name);
LLVMValueRef LLVMBuildSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildSwitch(LLVMBuilderRef, LLVMValueRef V, LLVMBasicBlockRef Else, uint NumCases);
LLVMValueRef LLVMBuildTrunc(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildTruncOrBitCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildUDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildUIToFP(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildURem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildUnreachable(LLVMBuilderRef);
LLVMValueRef LLVMBuildVAArg(LLVMBuilderRef, LLVMValueRef List, LLVMTypeRef Ty, const(char)* Name);
LLVMValueRef LLVMBuildXor(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildZExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildZExtOrBitCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMMetadataRef LLVMBuilderGetDefaultFPMathTag(LLVMBuilderRef Builder);
void LLVMBuilderSetDefaultFPMathTag(LLVMBuilderRef Builder, LLVMMetadataRef FPMathTag);
void LLVMClearInsertionPosition(LLVMBuilderRef Builder);
LLVMModuleRef LLVMCloneModule(LLVMModuleRef M);
LLVMValueRef LLVMConstAdd(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
LLVMValueRef LLVMConstAddrSpaceCast(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
LLVMValueRef LLVMConstAllOnes(LLVMTypeRef Ty);
LLVMValueRef LLVMConstArray(LLVMTypeRef ElementTy, LLVMValueRef* ConstantVals, uint Length);
LLVMValueRef LLVMConstBitCast(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
LLVMValueRef LLVMConstExtractElement(LLVMValueRef VectorConstant, LLVMValueRef IndexConstant);
LLVMValueRef LLVMConstGEP2(LLVMTypeRef Ty, LLVMValueRef ConstantVal, LLVMValueRef* ConstantIndices, uint NumIndices);
LLVMValueRef LLVMConstInBoundsGEP2(LLVMTypeRef Ty, LLVMValueRef ConstantVal, LLVMValueRef* ConstantIndices, uint NumIndices);
LLVMValueRef LLVMConstInlineAsm(LLVMTypeRef Ty, const(char)* AsmString, const(char)* Constraints, LLVMBool HasSideEffects, LLVMBool IsAlignStack);
LLVMValueRef LLVMConstInsertElement(LLVMValueRef VectorConstant, LLVMValueRef ElementValueConstant, LLVMValueRef IndexConstant);
LLVMValueRef LLVMConstInt(LLVMTypeRef IntTy, ulong N, LLVMBool SignExtend);
long LLVMConstIntGetSExtValue(LLVMValueRef ConstantVal);
ulong LLVMConstIntGetZExtValue(LLVMValueRef ConstantVal);
LLVMValueRef LLVMConstIntOfArbitraryPrecision(LLVMTypeRef IntTy, uint NumWords, const(ulong)* Words);
LLVMValueRef LLVMConstIntOfString(LLVMTypeRef IntTy, const(char)* Text, ubyte Radix);
LLVMValueRef LLVMConstIntOfStringAndSize(LLVMTypeRef IntTy, const(char)* Text, uint SLen, ubyte Radix);
LLVMValueRef LLVMConstIntToPtr(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
LLVMValueRef LLVMConstNSWAdd(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
LLVMValueRef LLVMConstNSWNeg(LLVMValueRef ConstantVal);
LLVMValueRef LLVMConstNSWSub(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
LLVMValueRef LLVMConstNUWAdd(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
LLVMValueRef LLVMConstNUWNeg(LLVMValueRef ConstantVal);
LLVMValueRef LLVMConstNUWSub(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
LLVMValueRef LLVMConstNamedStruct(LLVMTypeRef StructTy, LLVMValueRef* ConstantVals, uint Count);
LLVMValueRef LLVMConstNeg(LLVMValueRef ConstantVal);
LLVMValueRef LLVMConstNot(LLVMValueRef ConstantVal);
LLVMValueRef LLVMConstNull(LLVMTypeRef Ty);
LLVMValueRef LLVMConstPointerCast(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
LLVMValueRef LLVMConstPointerNull(LLVMTypeRef Ty);
LLVMValueRef LLVMConstPtrToInt(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
LLVMValueRef LLVMConstReal(LLVMTypeRef RealTy, double N);
double LLVMConstRealGetDouble(LLVMValueRef ConstantVal, LLVMBool* losesInfo);
LLVMValueRef LLVMConstRealOfString(LLVMTypeRef RealTy, const(char)* Text);
LLVMValueRef LLVMConstRealOfStringAndSize(LLVMTypeRef RealTy, const(char)* Text, uint SLen);
LLVMValueRef LLVMConstShuffleVector(LLVMValueRef VectorAConstant, LLVMValueRef VectorBConstant, LLVMValueRef MaskConstant);
LLVMValueRef LLVMConstString(const(char)* Str, uint Length, LLVMBool DontNullTerminate);
LLVMValueRef LLVMConstStringInContext(LLVMContextRef C, const(char)* Str, uint Length, LLVMBool DontNullTerminate);
LLVMValueRef LLVMConstStruct(LLVMValueRef* ConstantVals, uint Count, LLVMBool Packed);
LLVMValueRef LLVMConstStructInContext(LLVMContextRef C, LLVMValueRef* ConstantVals, uint Count, LLVMBool Packed);
LLVMValueRef LLVMConstSub(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
LLVMValueRef LLVMConstTrunc(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
LLVMValueRef LLVMConstTruncOrBitCast(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
LLVMValueRef LLVMConstVector(LLVMValueRef* ScalarConstantVals, uint Size);
LLVMValueRef LLVMConstXor(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
LLVMContextRef LLVMContextCreate();
void LLVMContextDispose(LLVMContextRef C);
void* LLVMContextGetDiagnosticContext(LLVMContextRef C);
LLVMDiagnosticHandler LLVMContextGetDiagnosticHandler(LLVMContextRef C);
void LLVMContextSetDiagnosticHandler(LLVMContextRef C, LLVMDiagnosticHandler Handler, void* DiagnosticContext);
void LLVMContextSetDiscardValueNames(LLVMContextRef C, LLVMBool Discard);
void LLVMContextSetYieldCallback(LLVMContextRef C, LLVMYieldCallback Callback, void* OpaqueHandle);
LLVMBool LLVMContextShouldDiscardValueNames(LLVMContextRef C);
LLVMModuleFlagEntry* LLVMCopyModuleFlagsMetadata(LLVMModuleRef M, size_t* Len);
uint LLVMCountBasicBlocks(LLVMValueRef Fn);
uint LLVMCountIncoming(LLVMValueRef PhiNode);
uint LLVMCountParamTypes(LLVMTypeRef FunctionTy);
uint LLVMCountParams(LLVMValueRef Fn);
uint LLVMCountStructElementTypes(LLVMTypeRef StructTy);
LLVMBasicBlockRef LLVMCreateBasicBlockInContext(LLVMContextRef C, const(char)* Name);
LLVMBuilderRef LLVMCreateBuilder();
LLVMBuilderRef LLVMCreateBuilderInContext(LLVMContextRef C);
LLVMAttributeRef LLVMCreateEnumAttribute(LLVMContextRef C, uint KindID, ulong Val);
LLVMPassManagerRef LLVMCreateFunctionPassManager(LLVMModuleProviderRef MP);
LLVMPassManagerRef LLVMCreateFunctionPassManagerForModule(LLVMModuleRef M);
LLVMBool LLVMCreateMemoryBufferWithContentsOfFile(const(char)* Path, LLVMMemoryBufferRef* OutMemBuf, char** OutMessage);
LLVMMemoryBufferRef LLVMCreateMemoryBufferWithMemoryRange(const(char)* InputData, size_t InputDataLength, const(char)* BufferName, LLVMBool RequiresNullTerminator);
LLVMMemoryBufferRef LLVMCreateMemoryBufferWithMemoryRangeCopy(const(char)* InputData, size_t InputDataLength, const(char)* BufferName);
LLVMBool LLVMCreateMemoryBufferWithSTDIN(LLVMMemoryBufferRef* OutMemBuf, char** OutMessage);
char* LLVMCreateMessage(const(char)* Message);
LLVMModuleProviderRef LLVMCreateModuleProviderForExistingModule(LLVMModuleRef M);
LLVMPassManagerRef LLVMCreatePassManager();
LLVMAttributeRef LLVMCreateStringAttribute(LLVMContextRef C, const(char)* K, uint KLength, const(char)* V, uint VLength);
void LLVMDeleteBasicBlock(LLVMBasicBlockRef BB);
void LLVMDeleteFunction(LLVMValueRef Fn);
void LLVMDeleteGlobal(LLVMValueRef GlobalVar);
void LLVMDisposeBuilder(LLVMBuilderRef Builder);
void LLVMDisposeMemoryBuffer(LLVMMemoryBufferRef MemBuf);
void LLVMDisposeMessage(char* Message);
void LLVMDisposeModule(LLVMModuleRef M);
void LLVMDisposeModuleFlagsMetadata(LLVMModuleFlagEntry* Entries);
void LLVMDisposeModuleProvider(LLVMModuleProviderRef M);
void LLVMDisposePassManager(LLVMPassManagerRef PM);
void LLVMDisposeValueMetadataEntries(LLVMValueMetadataEntry* Entries);
LLVMTypeRef LLVMDoubleType();
LLVMTypeRef LLVMDoubleTypeInContext(LLVMContextRef C);
void LLVMDumpModule(LLVMModuleRef M);
void LLVMDumpType(LLVMTypeRef Val);
void LLVMDumpValue(LLVMValueRef Val);
void LLVMEraseGlobalIFunc(LLVMValueRef IFunc);
LLVMTypeRef LLVMFP128Type();
LLVMTypeRef LLVMFP128TypeInContext(LLVMContextRef C);
LLVMBool LLVMFinalizeFunctionPassManager(LLVMPassManagerRef FPM);
LLVMTypeRef LLVMFloatType();
LLVMTypeRef LLVMFloatTypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMFunctionType(LLVMTypeRef ReturnType, LLVMTypeRef* ParamTypes, uint ParamCount, LLVMBool IsVarArg);
uint LLVMGetAlignment(LLVMValueRef V);
LLVMTypeRef LLVMGetAllocatedType(LLVMValueRef Alloca);
LLVMValueRef LLVMGetArgOperand(LLVMValueRef Funclet, uint i);
uint LLVMGetArrayLength(LLVMTypeRef ArrayTy);
const(char)* LLVMGetAsString(LLVMValueRef c, size_t* Length);
LLVMAtomicRMWBinOp LLVMGetAtomicRMWBinOp(LLVMValueRef AtomicRMWInst);
uint LLVMGetAttributeCountAtIndex(LLVMValueRef F, LLVMAttributeIndex Idx);
void LLVMGetAttributesAtIndex(LLVMValueRef F, LLVMAttributeIndex Idx, LLVMAttributeRef* Attrs);
const(char)* LLVMGetBasicBlockName(LLVMBasicBlockRef BB);
LLVMValueRef LLVMGetBasicBlockParent(LLVMBasicBlockRef BB);
LLVMValueRef LLVMGetBasicBlockTerminator(LLVMBasicBlockRef BB);
void LLVMGetBasicBlocks(LLVMValueRef Fn, LLVMBasicBlockRef* BasicBlocks);
size_t LLVMGetBufferSize(LLVMMemoryBufferRef MemBuf);
const(char)* LLVMGetBufferStart(LLVMMemoryBufferRef MemBuf);
uint LLVMGetCallSiteAttributeCount(LLVMValueRef C, LLVMAttributeIndex Idx);
void LLVMGetCallSiteAttributes(LLVMValueRef C, LLVMAttributeIndex Idx, LLVMAttributeRef* Attrs);
LLVMAttributeRef LLVMGetCallSiteEnumAttribute(LLVMValueRef C, LLVMAttributeIndex Idx, uint KindID);
LLVMAttributeRef LLVMGetCallSiteStringAttribute(LLVMValueRef C, LLVMAttributeIndex Idx, const(char)* K, uint KLen);
LLVMTypeRef LLVMGetCalledFunctionType(LLVMValueRef C);
LLVMValueRef LLVMGetCalledValue(LLVMValueRef Instr);
LLVMValueRef LLVMGetClause(LLVMValueRef LandingPad, uint Idx);
LLVMAtomicOrdering LLVMGetCmpXchgFailureOrdering(LLVMValueRef CmpXchgInst);
LLVMAtomicOrdering LLVMGetCmpXchgSuccessOrdering(LLVMValueRef CmpXchgInst);
LLVMValueRef LLVMGetCondition(LLVMValueRef Branch);
LLVMOpcode LLVMGetConstOpcode(LLVMValueRef ConstantVal);
LLVMValueRef LLVMGetCurrentDebugLocation(LLVMBuilderRef Builder);
LLVMMetadataRef LLVMGetCurrentDebugLocation2(LLVMBuilderRef Builder);
LLVMDLLStorageClass LLVMGetDLLStorageClass(LLVMValueRef Global);
const(char)* LLVMGetDataLayout(LLVMModuleRef M);
const(char)* LLVMGetDataLayoutStr(LLVMModuleRef M);
uint LLVMGetDebugLocColumn(LLVMValueRef Val);
const(char)* LLVMGetDebugLocDirectory(LLVMValueRef Val, uint* Length);
const(char)* LLVMGetDebugLocFilename(LLVMValueRef Val, uint* Length);
uint LLVMGetDebugLocLine(LLVMValueRef Val);
char* LLVMGetDiagInfoDescription(LLVMDiagnosticInfoRef DI);
LLVMDiagnosticSeverity LLVMGetDiagInfoSeverity(LLVMDiagnosticInfoRef DI);
LLVMValueRef LLVMGetElementAsConstant(LLVMValueRef C, uint idx);
LLVMTypeRef LLVMGetElementType(LLVMTypeRef Ty);
LLVMBasicBlockRef LLVMGetEntryBasicBlock(LLVMValueRef Fn);
LLVMAttributeRef LLVMGetEnumAttributeAtIndex(LLVMValueRef F, LLVMAttributeIndex Idx, uint KindID);
uint LLVMGetEnumAttributeKind(LLVMAttributeRef A);
uint LLVMGetEnumAttributeKindForName(const(char)* Name, size_t SLen);
ulong LLVMGetEnumAttributeValue(LLVMAttributeRef A);
LLVMRealPredicate LLVMGetFCmpPredicate(LLVMValueRef Inst);
LLVMBasicBlockRef LLVMGetFirstBasicBlock(LLVMValueRef Fn);
LLVMValueRef LLVMGetFirstFunction(LLVMModuleRef M);
LLVMValueRef LLVMGetFirstGlobal(LLVMModuleRef M);
LLVMValueRef LLVMGetFirstGlobalAlias(LLVMModuleRef M);
LLVMValueRef LLVMGetFirstGlobalIFunc(LLVMModuleRef M);
LLVMValueRef LLVMGetFirstInstruction(LLVMBasicBlockRef BB);
LLVMNamedMDNodeRef LLVMGetFirstNamedMetadata(LLVMModuleRef M);
LLVMValueRef LLVMGetFirstParam(LLVMValueRef Fn);
LLVMUseRef LLVMGetFirstUse(LLVMValueRef Val);
uint LLVMGetFunctionCallConv(LLVMValueRef Fn);
const(char)* LLVMGetGC(LLVMValueRef Fn);
LLVMContextRef LLVMGetGlobalContext();
LLVMValueRef LLVMGetGlobalIFuncResolver(LLVMValueRef IFunc);
LLVMModuleRef LLVMGetGlobalParent(LLVMValueRef Global);
void LLVMGetHandlers(LLVMValueRef CatchSwitch, LLVMBasicBlockRef* Handlers);
LLVMIntPredicate LLVMGetICmpPredicate(LLVMValueRef Inst);
LLVMBasicBlockRef LLVMGetIncomingBlock(LLVMValueRef PhiNode, uint Index);
LLVMValueRef LLVMGetIncomingValue(LLVMValueRef PhiNode, uint Index);
const(uint)* LLVMGetIndices(LLVMValueRef Inst);
LLVMValueRef LLVMGetInitializer(LLVMValueRef GlobalVar);
LLVMBasicBlockRef LLVMGetInsertBlock(LLVMBuilderRef Builder);
uint LLVMGetInstructionCallConv(LLVMValueRef Instr);
LLVMOpcode LLVMGetInstructionOpcode(LLVMValueRef Inst);
LLVMBasicBlockRef LLVMGetInstructionParent(LLVMValueRef Inst);
uint LLVMGetIntTypeWidth(LLVMTypeRef IntegerTy);
LLVMValueRef LLVMGetIntrinsicDeclaration(LLVMModuleRef Mod, uint ID, LLVMTypeRef* ParamTypes, size_t ParamCount);
uint LLVMGetIntrinsicID(LLVMValueRef Fn);
LLVMBasicBlockRef LLVMGetLastBasicBlock(LLVMValueRef Fn);
uint LLVMGetLastEnumAttributeKind();
LLVMValueRef LLVMGetLastFunction(LLVMModuleRef M);
LLVMValueRef LLVMGetLastGlobal(LLVMModuleRef M);
LLVMValueRef LLVMGetLastGlobalAlias(LLVMModuleRef M);
LLVMValueRef LLVMGetLastGlobalIFunc(LLVMModuleRef M);
LLVMValueRef LLVMGetLastInstruction(LLVMBasicBlockRef BB);
LLVMNamedMDNodeRef LLVMGetLastNamedMetadata(LLVMModuleRef M);
LLVMValueRef LLVMGetLastParam(LLVMValueRef Fn);
LLVMLinkage LLVMGetLinkage(LLVMValueRef Global);
uint LLVMGetMDKindID(const(char)* Name, uint SLen);
uint LLVMGetMDKindIDInContext(LLVMContextRef C, const(char)* Name, uint SLen);
uint LLVMGetMDNodeNumOperands(LLVMValueRef V);
void LLVMGetMDNodeOperands(LLVMValueRef V, LLVMValueRef* Dest);
const(char)* LLVMGetMDString(LLVMValueRef V, uint* Length);
LLVMValueRef LLVMGetMetadata(LLVMValueRef Val, uint KindID);
LLVMContextRef LLVMGetModuleContext(LLVMModuleRef M);
LLVMMetadataRef LLVMGetModuleFlag(LLVMModuleRef M, const(char)* Key, size_t KeyLen);
const(char)* LLVMGetModuleIdentifier(LLVMModuleRef M, size_t* Len);
const(char)* LLVMGetModuleInlineAsm(LLVMModuleRef M, size_t* Len);
LLVMValueRef LLVMGetNamedFunction(LLVMModuleRef M, const(char)* Name);
LLVMValueRef LLVMGetNamedGlobal(LLVMModuleRef M, const(char)* Name);
LLVMValueRef LLVMGetNamedGlobalAlias(LLVMModuleRef M, const(char)* Name, size_t NameLen);
LLVMValueRef LLVMGetNamedGlobalIFunc(LLVMModuleRef M, const(char)* Name, size_t NameLen);
LLVMNamedMDNodeRef LLVMGetNamedMetadata(LLVMModuleRef M, const(char)* Name, size_t NameLen);
const(char)* LLVMGetNamedMetadataName(LLVMNamedMDNodeRef NamedMD, size_t* NameLen);
uint LLVMGetNamedMetadataNumOperands(LLVMModuleRef M, const(char)* Name);
void LLVMGetNamedMetadataOperands(LLVMModuleRef M, const(char)* Name, LLVMValueRef* Dest);
LLVMBasicBlockRef LLVMGetNextBasicBlock(LLVMBasicBlockRef BB);
LLVMValueRef LLVMGetNextFunction(LLVMValueRef Fn);
LLVMValueRef LLVMGetNextGlobal(LLVMValueRef GlobalVar);
LLVMValueRef LLVMGetNextGlobalAlias(LLVMValueRef GA);
LLVMValueRef LLVMGetNextGlobalIFunc(LLVMValueRef IFunc);
LLVMValueRef LLVMGetNextInstruction(LLVMValueRef Inst);
LLVMNamedMDNodeRef LLVMGetNextNamedMetadata(LLVMNamedMDNodeRef NamedMDNode);
LLVMValueRef LLVMGetNextParam(LLVMValueRef Arg);
LLVMUseRef LLVMGetNextUse(LLVMUseRef U);
LLVMBasicBlockRef LLVMGetNormalDest(LLVMValueRef InvokeInst);
uint LLVMGetNumArgOperands(LLVMValueRef Instr);
uint LLVMGetNumClauses(LLVMValueRef LandingPad);
uint LLVMGetNumContainedTypes(LLVMTypeRef Tp);
uint LLVMGetNumHandlers(LLVMValueRef CatchSwitch);
uint LLVMGetNumIndices(LLVMValueRef Inst);
int LLVMGetNumOperands(LLVMValueRef Val);
uint LLVMGetNumSuccessors(LLVMValueRef Term);
LLVMValueRef LLVMGetOperand(LLVMValueRef Val, uint Index);
LLVMUseRef LLVMGetOperandUse(LLVMValueRef Val, uint Index);
LLVMNamedMDNodeRef LLVMGetOrInsertNamedMetadata(LLVMModuleRef M, const(char)* Name, size_t NameLen);
LLVMAtomicOrdering LLVMGetOrdering(LLVMValueRef MemoryAccessInst);
LLVMValueRef LLVMGetParam(LLVMValueRef Fn, uint Index);
LLVMValueRef LLVMGetParamParent(LLVMValueRef Inst);
void LLVMGetParamTypes(LLVMTypeRef FunctionTy, LLVMTypeRef* Dest);
void LLVMGetParams(LLVMValueRef Fn, LLVMValueRef* Params);
LLVMValueRef LLVMGetParentCatchSwitch(LLVMValueRef CatchPad);
LLVMValueRef LLVMGetPersonalityFn(LLVMValueRef Fn);
uint LLVMGetPointerAddressSpace(LLVMTypeRef PointerTy);
LLVMBasicBlockRef LLVMGetPreviousBasicBlock(LLVMBasicBlockRef BB);
LLVMValueRef LLVMGetPreviousFunction(LLVMValueRef Fn);
LLVMValueRef LLVMGetPreviousGlobal(LLVMValueRef GlobalVar);
LLVMValueRef LLVMGetPreviousGlobalAlias(LLVMValueRef GA);
LLVMValueRef LLVMGetPreviousGlobalIFunc(LLVMValueRef IFunc);
LLVMValueRef LLVMGetPreviousInstruction(LLVMValueRef Inst);
LLVMNamedMDNodeRef LLVMGetPreviousNamedMetadata(LLVMNamedMDNodeRef NamedMDNode);
LLVMValueRef LLVMGetPreviousParam(LLVMValueRef Arg);
LLVMTypeRef LLVMGetReturnType(LLVMTypeRef FunctionTy);
const(char)* LLVMGetSection(LLVMValueRef Global);
const(char)* LLVMGetSourceFileName(LLVMModuleRef M, size_t* Len);
LLVMAttributeRef LLVMGetStringAttributeAtIndex(LLVMValueRef F, LLVMAttributeIndex Idx, const(char)* K, uint KLen);
const(char)* LLVMGetStringAttributeKind(LLVMAttributeRef A, uint* Length);
const(char)* LLVMGetStringAttributeValue(LLVMAttributeRef A, uint* Length);
void LLVMGetStructElementTypes(LLVMTypeRef StructTy, LLVMTypeRef* Dest);
const(char)* LLVMGetStructName(LLVMTypeRef Ty);
void LLVMGetSubtypes(LLVMTypeRef Tp, LLVMTypeRef* Arr);
LLVMBasicBlockRef LLVMGetSuccessor(LLVMValueRef Term, uint i);
LLVMBasicBlockRef LLVMGetSwitchDefaultDest(LLVMValueRef SwitchInstr);
const(char)* LLVMGetTarget(LLVMModuleRef M);
LLVMThreadLocalMode LLVMGetThreadLocalMode(LLVMValueRef GlobalVar);
LLVMTypeRef LLVMGetTypeByName(LLVMModuleRef M, const(char)* Name);
LLVMContextRef LLVMGetTypeContext(LLVMTypeRef Ty);
LLVMTypeKind LLVMGetTypeKind(LLVMTypeRef Ty);
LLVMValueRef LLVMGetUndef(LLVMTypeRef Ty);
LLVMUnnamedAddr LLVMGetUnnamedAddress(LLVMValueRef Global);
LLVMBasicBlockRef LLVMGetUnwindDest(LLVMValueRef InvokeInst);
LLVMValueRef LLVMGetUsedValue(LLVMUseRef U);
LLVMValueRef LLVMGetUser(LLVMUseRef U);
LLVMValueKind LLVMGetValueKind(LLVMValueRef Val);
const(char)* LLVMGetValueName(LLVMValueRef Val);
const(char)* LLVMGetValueName2(LLVMValueRef Val, size_t* Length);
uint LLVMGetVectorSize(LLVMTypeRef VectorTy);
LLVMVisibility LLVMGetVisibility(LLVMValueRef Global);
LLVMBool LLVMGetVolatile(LLVMValueRef MemoryAccessInst);
LLVMBool LLVMGetWeak(LLVMValueRef CmpXchgInst);
void LLVMGlobalClearMetadata(LLVMValueRef Global);
LLVMValueMetadataEntry* LLVMGlobalCopyAllMetadata(LLVMValueRef Value, size_t* NumEntries);
void LLVMGlobalEraseMetadata(LLVMValueRef Global, uint Kind);
LLVMTypeRef LLVMGlobalGetValueType(LLVMValueRef Global);
void LLVMGlobalSetMetadata(LLVMValueRef Global, uint Kind, LLVMMetadataRef MD);
LLVMTypeRef LLVMHalfType();
LLVMTypeRef LLVMHalfTypeInContext(LLVMContextRef C);
int LLVMHasMetadata(LLVMValueRef Val);
LLVMBool LLVMHasPersonalityFn(LLVMValueRef Fn);
LLVMBool LLVMHasUnnamedAddr(LLVMValueRef Global);
LLVMBool LLVMInitializeFunctionPassManager(LLVMPassManagerRef FPM);
LLVMBasicBlockRef LLVMInsertBasicBlock(LLVMBasicBlockRef InsertBeforeBB, const(char)* Name);
LLVMBasicBlockRef LLVMInsertBasicBlockInContext(LLVMContextRef C, LLVMBasicBlockRef BB, const(char)* Name);
void LLVMInsertExistingBasicBlockAfterInsertBlock(LLVMBuilderRef Builder, LLVMBasicBlockRef BB);
void LLVMInsertIntoBuilder(LLVMBuilderRef Builder, LLVMValueRef Instr);
void LLVMInsertIntoBuilderWithName(LLVMBuilderRef Builder, LLVMValueRef Instr, const(char)* Name);
LLVMValueRef LLVMInstructionClone(LLVMValueRef Inst);
void LLVMInstructionEraseFromParent(LLVMValueRef Inst);
LLVMValueMetadataEntry* LLVMInstructionGetAllMetadataOtherThanDebugLoc(LLVMValueRef Instr, size_t* NumEntries);
void LLVMInstructionRemoveFromParent(LLVMValueRef Inst);
LLVMTypeRef LLVMInt128Type();
LLVMTypeRef LLVMInt128TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt16Type();
LLVMTypeRef LLVMInt16TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt1Type();
LLVMTypeRef LLVMInt1TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt32Type();
LLVMTypeRef LLVMInt32TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt64Type();
LLVMTypeRef LLVMInt64TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt8Type();
LLVMTypeRef LLVMInt8TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMIntType(uint NumBits);
LLVMTypeRef LLVMIntTypeInContext(LLVMContextRef C, uint NumBits);
char* LLVMIntrinsicCopyOverloadedName(uint ID, LLVMTypeRef* ParamTypes, size_t ParamCount, size_t* NameLength);
const(char)* LLVMIntrinsicGetName(uint ID, size_t* NameLength);
LLVMTypeRef LLVMIntrinsicGetType(LLVMContextRef Ctx, uint ID, LLVMTypeRef* ParamTypes, size_t ParamCount);
LLVMBool LLVMIntrinsicIsOverloaded(uint ID);
LLVMValueRef LLVMIsAAddrSpaceCastInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAAllocaInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAArgument(LLVMValueRef Val);
LLVMValueRef LLVMIsAAtomicCmpXchgInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAAtomicRMWInst(LLVMValueRef Val);
LLVMValueRef LLVMIsABasicBlock(LLVMValueRef Val);
LLVMValueRef LLVMIsABinaryOperator(LLVMValueRef Val);
LLVMValueRef LLVMIsABitCastInst(LLVMValueRef Val);
LLVMValueRef LLVMIsABlockAddress(LLVMValueRef Val);
LLVMValueRef LLVMIsABranchInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACallBrInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACallInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACastInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACatchPadInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACatchReturnInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACatchSwitchInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACleanupPadInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACleanupReturnInst(LLVMValueRef Val);
LLVMValueRef LLVMIsACmpInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstant(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantAggregateZero(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantArray(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantDataArray(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantDataSequential(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantDataVector(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantExpr(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantFP(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantInt(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantPointerNull(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantStruct(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantTokenNone(LLVMValueRef Val);
LLVMValueRef LLVMIsAConstantVector(LLVMValueRef Val);
LLVMValueRef LLVMIsADbgDeclareInst(LLVMValueRef Val);
LLVMValueRef LLVMIsADbgInfoIntrinsic(LLVMValueRef Val);
LLVMValueRef LLVMIsADbgLabelInst(LLVMValueRef Val);
LLVMValueRef LLVMIsADbgVariableIntrinsic(LLVMValueRef Val);
LLVMValueRef LLVMIsAExtractElementInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAExtractValueInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFCmpInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFPExtInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFPToSIInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFPToUIInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFPTruncInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFenceInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFreezeInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFuncletPadInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAFunction(LLVMValueRef Val);
LLVMValueRef LLVMIsAGetElementPtrInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAGlobalAlias(LLVMValueRef Val);
LLVMValueRef LLVMIsAGlobalIFunc(LLVMValueRef Val);
LLVMValueRef LLVMIsAGlobalObject(LLVMValueRef Val);
LLVMValueRef LLVMIsAGlobalValue(LLVMValueRef Val);
LLVMValueRef LLVMIsAGlobalVariable(LLVMValueRef Val);
LLVMValueRef LLVMIsAICmpInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAIndirectBrInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAInlineAsm(LLVMValueRef Val);
LLVMValueRef LLVMIsAInsertElementInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAInsertValueInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAInstruction(LLVMValueRef Val);
LLVMValueRef LLVMIsAIntToPtrInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAIntrinsicInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAInvokeInst(LLVMValueRef Val);
LLVMValueRef LLVMIsALandingPadInst(LLVMValueRef Val);
LLVMValueRef LLVMIsALoadInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAMDNode(LLVMValueRef Val);
LLVMValueRef LLVMIsAMDString(LLVMValueRef Val);
LLVMValueRef LLVMIsAMemCpyInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAMemIntrinsic(LLVMValueRef Val);
LLVMValueRef LLVMIsAMemMoveInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAMemSetInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAPHINode(LLVMValueRef Val);
LLVMValueRef LLVMIsAPtrToIntInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAResumeInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAReturnInst(LLVMValueRef Val);
LLVMValueRef LLVMIsASExtInst(LLVMValueRef Val);
LLVMValueRef LLVMIsASIToFPInst(LLVMValueRef Val);
LLVMValueRef LLVMIsASelectInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAShuffleVectorInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAStoreInst(LLVMValueRef Val);
LLVMValueRef LLVMIsASwitchInst(LLVMValueRef Val);
LLVMValueRef LLVMIsATerminatorInst(LLVMValueRef Inst);
LLVMValueRef LLVMIsATruncInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAUIToFPInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAUnaryInstruction(LLVMValueRef Val);
LLVMValueRef LLVMIsAUnaryOperator(LLVMValueRef Val);
LLVMValueRef LLVMIsAUndefValue(LLVMValueRef Val);
LLVMValueRef LLVMIsAUnreachableInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAUser(LLVMValueRef Val);
LLVMValueRef LLVMIsAVAArgInst(LLVMValueRef Val);
LLVMValueRef LLVMIsAZExtInst(LLVMValueRef Val);
LLVMBool LLVMIsAtomicSingleThread(LLVMValueRef AtomicInst);
LLVMBool LLVMIsCleanup(LLVMValueRef LandingPad);
LLVMBool LLVMIsConditional(LLVMValueRef Branch);
LLVMBool LLVMIsConstant(LLVMValueRef Val);
LLVMBool LLVMIsConstantString(LLVMValueRef c);
LLVMBool LLVMIsDeclaration(LLVMValueRef Global);
LLVMBool LLVMIsEnumAttribute(LLVMAttributeRef A);
LLVMBool LLVMIsExternallyInitialized(LLVMValueRef GlobalVar);
LLVMBool LLVMIsFunctionVarArg(LLVMTypeRef FunctionTy);
LLVMBool LLVMIsGlobalConstant(LLVMValueRef GlobalVar);
LLVMBool LLVMIsInBounds(LLVMValueRef GEP);
LLVMBool LLVMIsLiteralStruct(LLVMTypeRef StructTy);
LLVMBool LLVMIsMultithreaded();
LLVMBool LLVMIsNull(LLVMValueRef Val);
LLVMBool LLVMIsOpaqueStruct(LLVMTypeRef StructTy);
LLVMBool LLVMIsPackedStruct(LLVMTypeRef StructTy);
LLVMBool LLVMIsStringAttribute(LLVMAttributeRef A);
LLVMBool LLVMIsTailCall(LLVMValueRef CallInst);
LLVMBool LLVMIsThreadLocal(LLVMValueRef GlobalVar);
LLVMBool LLVMIsUndef(LLVMValueRef Val);
LLVMTypeRef LLVMLabelType();
LLVMTypeRef LLVMLabelTypeInContext(LLVMContextRef C);
uint LLVMLookupIntrinsicID(const(char)* Name, size_t NameLen);
LLVMValueRef LLVMMDNode(LLVMValueRef* Vals, uint Count);
LLVMValueRef LLVMMDNodeInContext(LLVMContextRef C, LLVMValueRef* Vals, uint Count);
LLVMMetadataRef LLVMMDNodeInContext2(LLVMContextRef C, LLVMMetadataRef* MDs, size_t Count);
LLVMValueRef LLVMMDString(const(char)* Str, uint SLen);
LLVMValueRef LLVMMDStringInContext(LLVMContextRef C, const(char)* Str, uint SLen);
LLVMMetadataRef LLVMMDStringInContext2(LLVMContextRef C, const(char)* Str, size_t SLen);
LLVMValueRef LLVMMetadataAsValue(LLVMContextRef C, LLVMMetadataRef MD);
LLVMTypeRef LLVMMetadataTypeInContext(LLVMContextRef C);
LLVMModuleRef LLVMModuleCreateWithName(const(char)* ModuleID);
LLVMModuleRef LLVMModuleCreateWithNameInContext(const(char)* ModuleID, LLVMContextRef C);
LLVMModuleFlagBehavior LLVMModuleFlagEntriesGetFlagBehavior(LLVMModuleFlagEntry* Entries, uint Index);
const(char)* LLVMModuleFlagEntriesGetKey(LLVMModuleFlagEntry* Entries, uint Index, size_t* Len);
LLVMMetadataRef LLVMModuleFlagEntriesGetMetadata(LLVMModuleFlagEntry* Entries, uint Index);
void LLVMMoveBasicBlockAfter(LLVMBasicBlockRef BB, LLVMBasicBlockRef MovePos);
void LLVMMoveBasicBlockBefore(LLVMBasicBlockRef BB, LLVMBasicBlockRef MovePos);
LLVMTypeRef LLVMPPCFP128Type();
LLVMTypeRef LLVMPPCFP128TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMPointerType(LLVMTypeRef ElementType, uint AddressSpace);
void LLVMPositionBuilder(LLVMBuilderRef Builder, LLVMBasicBlockRef Block, LLVMValueRef Instr);
void LLVMPositionBuilderAtEnd(LLVMBuilderRef Builder, LLVMBasicBlockRef Block);
void LLVMPositionBuilderBefore(LLVMBuilderRef Builder, LLVMValueRef Instr);
LLVMBool LLVMPrintModuleToFile(LLVMModuleRef M, const(char)* Filename, char** ErrorMessage);
char* LLVMPrintModuleToString(LLVMModuleRef M);
char* LLVMPrintTypeToString(LLVMTypeRef Val);
char* LLVMPrintValueToString(LLVMValueRef Val);
void LLVMRemoveBasicBlockFromParent(LLVMBasicBlockRef BB);
void LLVMRemoveCallSiteEnumAttribute(LLVMValueRef C, LLVMAttributeIndex Idx, uint KindID);
void LLVMRemoveCallSiteStringAttribute(LLVMValueRef C, LLVMAttributeIndex Idx, const(char)* K, uint KLen);
void LLVMRemoveEnumAttributeAtIndex(LLVMValueRef F, LLVMAttributeIndex Idx, uint KindID);
void LLVMRemoveGlobalIFunc(LLVMValueRef IFunc);
void LLVMRemoveStringAttributeAtIndex(LLVMValueRef F, LLVMAttributeIndex Idx, const(char)* K, uint KLen);
void LLVMReplaceAllUsesWith(LLVMValueRef OldVal, LLVMValueRef NewVal);
LLVMBool LLVMRunFunctionPassManager(LLVMPassManagerRef FPM, LLVMValueRef F);
LLVMBool LLVMRunPassManager(LLVMPassManagerRef PM, LLVMModuleRef M);
void LLVMSetAlignment(LLVMValueRef V, uint Bytes);
void LLVMSetArgOperand(LLVMValueRef Funclet, uint i, LLVMValueRef value);
void LLVMSetAtomicRMWBinOp(LLVMValueRef AtomicRMWInst, LLVMAtomicRMWBinOp BinOp);
void LLVMSetAtomicSingleThread(LLVMValueRef AtomicInst, LLVMBool SingleThread);
void LLVMSetCleanup(LLVMValueRef LandingPad, LLVMBool Val);
void LLVMSetCmpXchgFailureOrdering(LLVMValueRef CmpXchgInst, LLVMAtomicOrdering Ordering);
void LLVMSetCmpXchgSuccessOrdering(LLVMValueRef CmpXchgInst, LLVMAtomicOrdering Ordering);
void LLVMSetCondition(LLVMValueRef Branch, LLVMValueRef Cond);
void LLVMSetCurrentDebugLocation(LLVMBuilderRef Builder, LLVMValueRef L);
void LLVMSetCurrentDebugLocation2(LLVMBuilderRef Builder, LLVMMetadataRef Loc);
void LLVMSetDLLStorageClass(LLVMValueRef Global, LLVMDLLStorageClass Class);
void LLVMSetDataLayout(LLVMModuleRef M, const(char)* DataLayoutStr);
void LLVMSetExternallyInitialized(LLVMValueRef GlobalVar, LLVMBool IsExtInit);
void LLVMSetFunctionCallConv(LLVMValueRef Fn, uint CC);
void LLVMSetGC(LLVMValueRef Fn, const(char)* Name);
void LLVMSetGlobalConstant(LLVMValueRef GlobalVar, LLVMBool IsConstant);
void LLVMSetGlobalIFuncResolver(LLVMValueRef IFunc, LLVMValueRef Resolver);
void LLVMSetInitializer(LLVMValueRef GlobalVar, LLVMValueRef ConstantVal);
void LLVMSetInstDebugLocation(LLVMBuilderRef Builder, LLVMValueRef Inst);
void LLVMSetInstructionCallConv(LLVMValueRef Instr, uint CC);
void LLVMSetIsInBounds(LLVMValueRef GEP, LLVMBool InBounds);
void LLVMSetLinkage(LLVMValueRef Global, LLVMLinkage Linkage);
void LLVMSetMetadata(LLVMValueRef Val, uint KindID, LLVMValueRef Node);
void LLVMSetModuleIdentifier(LLVMModuleRef M, const(char)* Ident, size_t Len);
void LLVMSetModuleInlineAsm(LLVMModuleRef M, const(char)* Asm);
void LLVMSetModuleInlineAsm2(LLVMModuleRef M, const(char)* Asm, size_t Len);
void LLVMSetNormalDest(LLVMValueRef InvokeInst, LLVMBasicBlockRef B);
void LLVMSetOperand(LLVMValueRef User, uint Index, LLVMValueRef Val);
void LLVMSetOrdering(LLVMValueRef MemoryAccessInst, LLVMAtomicOrdering Ordering);
void LLVMSetParamAlignment(LLVMValueRef Arg, uint Align);
void LLVMSetParentCatchSwitch(LLVMValueRef CatchPad, LLVMValueRef CatchSwitch);
void LLVMSetPersonalityFn(LLVMValueRef Fn, LLVMValueRef PersonalityFn);
void LLVMSetSection(LLVMValueRef Global, const(char)* Section);
void LLVMSetSourceFileName(LLVMModuleRef M, const(char)* Name, size_t Len);
void LLVMSetSuccessor(LLVMValueRef Term, uint i, LLVMBasicBlockRef block);
void LLVMSetTailCall(LLVMValueRef CallInst, LLVMBool IsTailCall);
void LLVMSetTarget(LLVMModuleRef M, const(char)* Triple);
void LLVMSetThreadLocal(LLVMValueRef GlobalVar, LLVMBool IsThreadLocal);
void LLVMSetThreadLocalMode(LLVMValueRef GlobalVar, LLVMThreadLocalMode Mode);
void LLVMSetUnnamedAddr(LLVMValueRef Global, LLVMBool HasUnnamedAddr);
void LLVMSetUnnamedAddress(LLVMValueRef Global, LLVMUnnamedAddr UnnamedAddr);
void LLVMSetUnwindDest(LLVMValueRef InvokeInst, LLVMBasicBlockRef B);
void LLVMSetValueName(LLVMValueRef Val, const(char)* Name);
void LLVMSetValueName2(LLVMValueRef Val, const(char)* Name, size_t NameLen);
void LLVMSetVisibility(LLVMValueRef Global, LLVMVisibility Viz);
void LLVMSetVolatile(LLVMValueRef MemoryAccessInst, LLVMBool IsVolatile);
void LLVMSetWeak(LLVMValueRef CmpXchgInst, LLVMBool IsWeak);
void LLVMShutdown();
LLVMValueRef LLVMSizeOf(LLVMTypeRef Ty);
LLVMBool LLVMStartMultithreaded();
void LLVMStopMultithreaded();
LLVMTypeRef LLVMStructCreateNamed(LLVMContextRef C, const(char)* Name);
LLVMTypeRef LLVMStructGetTypeAtIndex(LLVMTypeRef StructTy, uint i);
void LLVMStructSetBody(LLVMTypeRef StructTy, LLVMTypeRef* ElementTypes, uint ElementCount, LLVMBool Packed);
LLVMTypeRef LLVMStructType(LLVMTypeRef* ElementTypes, uint ElementCount, LLVMBool Packed);
LLVMTypeRef LLVMStructTypeInContext(LLVMContextRef C, LLVMTypeRef* ElementTypes, uint ElementCount, LLVMBool Packed);
LLVMTypeRef LLVMTokenTypeInContext(LLVMContextRef C);
LLVMBool LLVMTypeIsSized(LLVMTypeRef Ty);
LLVMTypeRef LLVMTypeOf(LLVMValueRef Val);
LLVMBasicBlockRef LLVMValueAsBasicBlock(LLVMValueRef Val);
LLVMMetadataRef LLVMValueAsMetadata(LLVMValueRef Val);
LLVMBool LLVMValueIsBasicBlock(LLVMValueRef Val);
uint LLVMValueMetadataEntriesGetKind(LLVMValueMetadataEntry* Entries, uint Index);
LLVMMetadataRef LLVMValueMetadataEntriesGetMetadata(LLVMValueMetadataEntry* Entries, uint Index);
LLVMTypeRef LLVMVectorType(LLVMTypeRef ElementType, uint ElementCount);
LLVMTypeRef LLVMVoidType();
LLVMTypeRef LLVMVoidTypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMX86FP80Type();
LLVMTypeRef LLVMX86FP80TypeInContext(LLVMContextRef C);
version(LLVMVersion18AndAbove) {
	LLVMValueRef LLVMGetInlineAsm(LLVMTypeRef Ty, const(char)* AsmString, size_t AsmStringSize, const(char)* Constraints, size_t ConstraintsSize, LLVMBool HasSideEffects, LLVMBool IsAlignStack, LLVMInlineAsmDialect Dialect, LLVMBool CanThrow);
} else version(LLVMVersion13AndAbove) {
	LLVMValueRef LLVMGetInlineAsm(LLVMTypeRef Ty, char* AsmString, size_t AsmStringSize, char* Constraints, size_t ConstraintsSize, LLVMBool HasSideEffects, LLVMBool IsAlignStack, LLVMInlineAsmDialect Dialect, LLVMBool CanThrow);
} else {
	LLVMValueRef LLVMGetInlineAsm(LLVMTypeRef Ty, char* AsmString, size_t AsmStringSize, char* Constraints, size_t ConstraintsSize, LLVMBool HasSideEffects, LLVMBool IsAlignStack, LLVMInlineAsmDialect Dialect);
}
version(LLVMVersion14AndAbove) {
	void LLVMSetInstrParamAlignment(LLVMValueRef Instr, LLVMAttributeIndex Idx, uint Align);
} else {
	void LLVMSetInstrParamAlignment(LLVMValueRef Instr, uint index, uint Align);
}
version(LLVMVersion15AndAbove) {
	// Removed
} else {
	LLVMValueRef LLVMConstExactSDiv(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstExactUDiv(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstExtractValue(LLVMValueRef AggConstant, uint* IdxList, uint NumIdx);
	LLVMValueRef LLVMConstFAdd(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstFDiv(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstFMul(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstFRem(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstFSub(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstInsertValue(LLVMValueRef AggConstant, LLVMValueRef ElementValueConstant, uint* IdxList, uint NumIdx);
	LLVMValueRef LLVMConstSDiv(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstSRem(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstUDiv(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstURem(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
}
version(LLVMVersion16AndAbove) {
	// Removed
} else {
	LLVMValueRef LLVMAddAlias(LLVMModuleRef M, LLVMTypeRef Ty, LLVMValueRef Aliasee, const(char)* Name);
	LLVMValueRef LLVMBuildCall(LLVMBuilderRef, LLVMValueRef Fn, LLVMValueRef* Args, uint NumArgs, const(char)* Name);
	LLVMValueRef LLVMBuildGEP(LLVMBuilderRef B, LLVMValueRef Pointer, LLVMValueRef* Indices, uint NumIndices, const(char)* Name);
	LLVMValueRef LLVMBuildInBoundsGEP(LLVMBuilderRef B, LLVMValueRef Pointer, LLVMValueRef* Indices, uint NumIndices, const(char)* Name);
	LLVMValueRef LLVMBuildInvoke(LLVMBuilderRef, LLVMValueRef Fn, LLVMValueRef* Args, uint NumArgs, LLVMBasicBlockRef Then, LLVMBasicBlockRef Catch, const(char)* Name);
	LLVMValueRef LLVMBuildLoad(LLVMBuilderRef, LLVMValueRef PointerVal, const(char)* Name);
	LLVMValueRef LLVMBuildPtrDiff(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
	LLVMValueRef LLVMBuildStructGEP(LLVMBuilderRef B, LLVMValueRef Pointer, uint Idx, const(char)* Name);
	LLVMValueRef LLVMConstFNeg(LLVMValueRef ConstantVal);
	LLVMValueRef LLVMConstGEP(LLVMValueRef ConstantVal, LLVMValueRef* ConstantIndices, uint NumIndices);
	LLVMValueRef LLVMConstInBoundsGEP(LLVMValueRef ConstantVal, LLVMValueRef* ConstantIndices, uint NumIndices);
}
version(LLVMVersion17AndAbove) {
	// Removed
} else {
	LLVMValueRef LLVMConstSelect(LLVMValueRef ConstantCondition, LLVMValueRef ConstantIfTrue, LLVMValueRef ConstantIfFalse);
	LLVMPassRegistryRef LLVMGetGlobalPassRegistry();
}
version(LLVMVersion18AndAbove) {
	// Removed
} else {
	LLVMValueRef LLVMConstAShr(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstAnd(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstFPCast(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstFPExt(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstFPToSI(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstFPToUI(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstFPTrunc(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstIntCast(LLVMValueRef ConstantVal, LLVMTypeRef ToType, LLVMBool isSigned);
	LLVMValueRef LLVMConstLShr(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstOr(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstSExt(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstSExtOrBitCast(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstSIToFP(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstUIToFP(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstZExt(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
	LLVMValueRef LLVMConstZExtOrBitCast(LLVMValueRef ConstantVal, LLVMTypeRef ToType);
}
version(LLVMVersion19AndAbove) {
	// Removed
} else {
	LLVMValueRef LLVMConstFCmp(LLVMRealPredicate Predicate, LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstICmp(LLVMIntPredicate Predicate, LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstShl(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
}
version(LLVMVersion20AndAbove) {
	// Removed
} else {
	LLVMTypeRef LLVMX86MMXType();
	LLVMTypeRef LLVMX86MMXTypeInContext(LLVMContextRef C);
}
version(LLVMVersion21AndAbove) {
	// Removed
} else {
	LLVMValueRef LLVMConstMul(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstNSWMul(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
	LLVMValueRef LLVMConstNUWMul(LLVMValueRef LHSConstant, LLVMValueRef RHSConstant);
}
version(LLVMVersion11AndAbove) {
	LLVMTypeRef LLVMBFloatType();
	LLVMTypeRef LLVMBFloatTypeInContext(LLVMContextRef C);
	int LLVMGetMaskValue(LLVMValueRef ShuffleVectorInst, uint Elt);
	uint LLVMGetNumMaskElements(LLVMValueRef ShuffleVectorInst);
	int LLVMGetUndefMaskElem();
}
version(LLVMVersion12AndAbove) {
	LLVMAttributeRef LLVMCreateTypeAttribute(LLVMContextRef C, uint KindID, LLVMTypeRef type_ref);
	LLVMValueRef LLVMGetPoison(LLVMTypeRef Ty);
	LLVMTypeRef LLVMGetTypeAttributeValue(LLVMAttributeRef A);
	LLVMTypeRef LLVMGetTypeByName2(LLVMContextRef C, const(char)* Name);
	LLVMValueRef LLVMIsAPoisonValue(LLVMValueRef Val);
	LLVMBool LLVMIsPoison(LLVMValueRef Val);
	LLVMBool LLVMIsTypeAttribute(LLVMAttributeRef A);
	LLVMTypeRef LLVMScalableVectorType(LLVMTypeRef ElementType, uint ElementCount);
	LLVMTypeRef LLVMX86AMXType();
	LLVMTypeRef LLVMX86AMXTypeInContext(LLVMContextRef C);
}
version(LLVMVersion13AndAbove) {
	char* LLVMIntrinsicCopyOverloadedName2(LLVMModuleRef Mod, uint ID, LLVMTypeRef* ParamTypes, size_t ParamCount, size_t* NameLength);
}
version(LLVMVersion14AndAbove) {
	LLVMValueRef LLVMAddAlias2(LLVMModuleRef M, LLVMTypeRef ValueTy, uint AddrSpace, LLVMValueRef Aliasee, const(char)* Name);
	void LLVMAddMetadataToInst(LLVMBuilderRef Builder, LLVMValueRef Inst);
	LLVMValueRef LLVMBuildPtrDiff2(LLVMBuilderRef, LLVMTypeRef ElemTy, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
	LLVMTypeRef LLVMGetGEPSourceElementType(LLVMValueRef GEP);
}
version(LLVMVersion15AndAbove) {
	void LLVMDeleteInstruction(LLVMValueRef Inst);
	LLVMValueRef LLVMGetAggregateElement(LLVMValueRef C, uint Idx);
	LLVMOpcode LLVMGetCastOpcode(LLVMValueRef Src, LLVMBool SrcIsSigned, LLVMTypeRef DestTy, LLVMBool DestIsSigned);
	LLVMTypeRef LLVMPointerTypeInContext(LLVMContextRef C, uint AddressSpace);
	LLVMBool LLVMPointerTypeIsOpaque(LLVMTypeRef Ty);
}
version(LLVMVersion17AndAbove) {
	// Removed
} else version(LLVMVersion15AndAbove) {
	void LLVMContextSetOpaquePointers(LLVMContextRef C, LLVMBool OpaquePointers);
}
version(LLVMVersion16AndAbove) {
	void LLVMGetVersion(uint* Major, uint* Minor, uint* Patch);
	LLVMTypeRef LLVMTargetExtTypeInContext(LLVMContextRef C, const(char)* Name, LLVMTypeRef* TypeParams, uint TypeParamCount, uint* IntParams, uint IntParamCount);
}
version(LLVMVersion17AndAbove) {
	LLVMTypeRef LLVMArrayType2(LLVMTypeRef ElementType, ulong ElementCount);
	LLVMValueRef LLVMConstArray2(LLVMTypeRef ElementTy, LLVMValueRef* ConstantVals, ulong Length);
	ulong LLVMGetArrayLength2(LLVMTypeRef ArrayTy);
	LLVMBool LLVMGetExact(LLVMValueRef DivOrShrInst);
	LLVMBool LLVMGetNSW(LLVMValueRef ArithInst);
	LLVMBool LLVMGetNUW(LLVMValueRef ArithInst);
	LLVMValueRef LLVMIsAValueAsMetadata(LLVMValueRef Val);
	void LLVMReplaceMDNodeOperandWith(LLVMValueRef V, uint Index, LLVMMetadataRef Replacement);
	void LLVMSetExact(LLVMValueRef DivOrShrInst, LLVMBool IsExact);
	void LLVMSetNSW(LLVMValueRef ArithInst, LLVMBool HasNSW);
	void LLVMSetNUW(LLVMValueRef ArithInst, LLVMBool HasNUW);
}
version(LLVMVersion18AndAbove) {
	LLVMValueRef LLVMBuildCallWithOperandBundles(LLVMBuilderRef, LLVMTypeRef, LLVMValueRef Fn, LLVMValueRef* Args, uint NumArgs, LLVMOperandBundleRef* Bundles, uint NumBundles, const(char)* Name);
	LLVMValueRef LLVMBuildInvokeWithOperandBundles(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Fn, LLVMValueRef* Args, uint NumArgs, LLVMBasicBlockRef Then, LLVMBasicBlockRef Catch, LLVMOperandBundleRef* Bundles, uint NumBundles, const(char)* Name);
	LLVMBool LLVMCanValueUseFastMathFlags(LLVMValueRef Inst);
	LLVMOperandBundleRef LLVMCreateOperandBundle(const(char)* Tag, size_t TagLen, LLVMValueRef* Args, uint NumArgs);
	void LLVMDisposeOperandBundle(LLVMOperandBundleRef Bundle);
	LLVMFastMathFlags LLVMGetFastMathFlags(LLVMValueRef FPMathInst);
	const(char)* LLVMGetInlineAsmAsmString(LLVMValueRef InlineAsmVal, size_t* Len);
	LLVMBool LLVMGetInlineAsmCanUnwind(LLVMValueRef InlineAsmVal);
	const(char)* LLVMGetInlineAsmConstraintString(LLVMValueRef InlineAsmVal, size_t* Len);
	LLVMInlineAsmDialect LLVMGetInlineAsmDialect(LLVMValueRef InlineAsmVal);
	LLVMTypeRef LLVMGetInlineAsmFunctionType(LLVMValueRef InlineAsmVal);
	LLVMBool LLVMGetInlineAsmHasSideEffects(LLVMValueRef InlineAsmVal);
	LLVMBool LLVMGetInlineAsmNeedsAlignedStack(LLVMValueRef InlineAsmVal);
	LLVMBool LLVMGetIsDisjoint(LLVMValueRef Inst);
	LLVMBool LLVMGetNNeg(LLVMValueRef NonNegInst);
	uint LLVMGetNumOperandBundleArgs(LLVMOperandBundleRef Bundle);
	uint LLVMGetNumOperandBundles(LLVMValueRef C);
	LLVMValueRef LLVMGetOperandBundleArgAtIndex(LLVMOperandBundleRef Bundle, uint Index);
	LLVMOperandBundleRef LLVMGetOperandBundleAtIndex(LLVMValueRef C, uint Index);
	const(char)* LLVMGetOperandBundleTag(LLVMOperandBundleRef Bundle, size_t* Len);
	LLVMTailCallKind LLVMGetTailCallKind(LLVMValueRef CallInst);
	void LLVMSetFastMathFlags(LLVMValueRef FPMathInst, LLVMFastMathFlags FMF);
	void LLVMSetIsDisjoint(LLVMValueRef Inst, LLVMBool IsDisjoint);
	void LLVMSetNNeg(LLVMValueRef NonNegInst, LLVMBool IsNonNeg);
	void LLVMSetTailCallKind(LLVMValueRef CallInst, LLVMTailCallKind kind);
}
version(LLVMVersion19AndAbove) {
	LLVMValueRef LLVMBuildCallBr(LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Fn, LLVMBasicBlockRef DefaultDest, LLVMBasicBlockRef* IndirectDests, uint NumIndirectDests, LLVMValueRef* Args, uint NumArgs, LLVMOperandBundleRef* Bundles, uint NumBundles, const(char)* Name);
	LLVMValueRef LLVMBuildGEPWithNoWrapFlags(LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Pointer, LLVMValueRef* Indices, uint NumIndices, const(char)* Name, LLVMGEPNoWrapFlags NoWrapFlags);
	LLVMValueRef LLVMConstGEPWithNoWrapFlags(LLVMTypeRef Ty, LLVMValueRef ConstantVal, LLVMValueRef* ConstantIndices, uint NumIndices, LLVMGEPNoWrapFlags NoWrapFlags);
	LLVMValueRef LLVMConstStringInContext2(LLVMContextRef C, const(char)* Str, size_t Length, LLVMBool DontNullTerminate);
	LLVMValueRef LLVMConstantPtrAuth(LLVMValueRef Ptr, LLVMValueRef Key, LLVMValueRef Disc, LLVMValueRef AddrDisc);
	LLVMAttributeRef LLVMCreateConstantRangeAttribute(LLVMContextRef C, uint KindID, uint NumBits, const(ulong)* LowerWords, const(ulong)* UpperWords);
	LLVMGEPNoWrapFlags LLVMGEPGetNoWrapFlags(LLVMValueRef GEP);
	void LLVMGEPSetNoWrapFlags(LLVMValueRef GEP, LLVMGEPNoWrapFlags NoWrapFlags);
	LLVMBasicBlockRef LLVMGetBlockAddressBasicBlock(LLVMValueRef BlockAddr);
	LLVMValueRef LLVMGetBlockAddressFunction(LLVMValueRef BlockAddr);
	LLVMBasicBlockRef LLVMGetCallBrDefaultDest(LLVMValueRef CallBr);
	LLVMBasicBlockRef LLVMGetCallBrIndirectDest(LLVMValueRef CallBr, uint Idx);
	uint LLVMGetCallBrNumIndirectDests(LLVMValueRef CallBr);
	LLVMValueRef LLVMGetConstantPtrAuthAddrDiscriminator(LLVMValueRef PtrAuth);
	LLVMValueRef LLVMGetConstantPtrAuthDiscriminator(LLVMValueRef PtrAuth);
	LLVMValueRef LLVMGetConstantPtrAuthKey(LLVMValueRef PtrAuth);
	LLVMValueRef LLVMGetConstantPtrAuthPointer(LLVMValueRef PtrAuth);
	LLVMValueRef LLVMGetPrefixData(LLVMValueRef Fn);
	LLVMValueRef LLVMGetPrologueData(LLVMValueRef Fn);
	uint LLVMGetTargetExtTypeIntParam(LLVMTypeRef TargetExtTy, uint Idx);
	const(char)* LLVMGetTargetExtTypeName(LLVMTypeRef TargetExtTy);
	uint LLVMGetTargetExtTypeNumIntParams(LLVMTypeRef TargetExtTy);
	uint LLVMGetTargetExtTypeNumTypeParams(LLVMTypeRef TargetExtTy);
	LLVMTypeRef LLVMGetTargetExtTypeTypeParam(LLVMTypeRef TargetExtTy, uint Idx);
	LLVMBool LLVMHasPrefixData(LLVMValueRef Fn);
	LLVMBool LLVMHasPrologueData(LLVMValueRef Fn);
	LLVMValueRef LLVMIsAConstantPtrAuth(LLVMValueRef Val);
	LLVMBool LLVMIsNewDbgInfoFormat(LLVMModuleRef M);
	void LLVMPositionBuilderBeforeDbgRecords(LLVMBuilderRef Builder, LLVMBasicBlockRef Block, LLVMValueRef Inst);
	void LLVMPositionBuilderBeforeInstrAndDbgRecords(LLVMBuilderRef Builder, LLVMValueRef Instr);
	char* LLVMPrintDbgRecordToString(LLVMDbgRecordRef Record);
	void LLVMSetIsNewDbgInfoFormat(LLVMModuleRef M, LLVMBool UseNewFormat);
	void LLVMSetPrefixData(LLVMValueRef Fn, LLVMValueRef prefixData);
	void LLVMSetPrologueData(LLVMValueRef Fn, LLVMValueRef prologueData);
}
version(LLVMVersion20AndAbove) {
	LLVMValueRef LLVMBuildAtomicCmpXchgSyncScope(LLVMBuilderRef B, LLVMValueRef Ptr, LLVMValueRef Cmp, LLVMValueRef New, LLVMAtomicOrdering SuccessOrdering, LLVMAtomicOrdering FailureOrdering, uint SSID);
	LLVMValueRef LLVMBuildAtomicRMWSyncScope(LLVMBuilderRef B, LLVMAtomicRMWBinOp op, LLVMValueRef PTR, LLVMValueRef Val, LLVMAtomicOrdering ordering, uint SSID);
	LLVMValueRef LLVMBuildFenceSyncScope(LLVMBuilderRef B, LLVMAtomicOrdering ordering, uint SSID, const(char)* Name);
	uint LLVMGetAtomicSyncScopeID(LLVMValueRef AtomicInst);
	LLVMContextRef LLVMGetBuilderContext(LLVMBuilderRef Builder);
	LLVMDbgRecordRef LLVMGetFirstDbgRecord(LLVMValueRef Inst);
	LLVMDbgRecordRef LLVMGetLastDbgRecord(LLVMValueRef Inst);
	LLVMValueRef LLVMGetNamedFunctionWithLength(LLVMModuleRef M, const(char)* Name, size_t Length);
	LLVMValueRef LLVMGetNamedGlobalWithLength(LLVMModuleRef M, const(char)* Name, size_t Length);
	LLVMDbgRecordRef LLVMGetNextDbgRecord(LLVMDbgRecordRef DbgRecord);
	LLVMDbgRecordRef LLVMGetPreviousDbgRecord(LLVMDbgRecordRef DbgRecord);
	uint LLVMGetSyncScopeID(LLVMContextRef C, const(char)* Name, size_t SLen);
	LLVMContextRef LLVMGetValueContext(LLVMValueRef Val);
	LLVMBool LLVMIsAtomic(LLVMValueRef Inst);
	void LLVMSetAtomicSyncScopeID(LLVMValueRef AtomicInst, uint SSID);
}
version(LLVMVersion21AndAbove) {
	LLVMValueRef LLVMConstDataArray(LLVMTypeRef ElementTy, const(char)* Data, size_t SizeInBytes);
	LLVMBool LLVMGetICmpSameSign(LLVMValueRef Inst);
	const(char)* LLVMGetRawDataValues(LLVMValueRef c, size_t* SizeInBytes);
	void LLVMSetICmpSameSign(LLVMValueRef Inst, LLVMBool SameSign);
}
