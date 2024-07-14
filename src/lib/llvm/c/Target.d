/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.Target;

public import lib.llvm.c.Types;


struct LLVMTargetData {} alias  LLVMTargetDataRef = LLVMTargetData*;
struct LLVMTargetLibraryInfo {} alias  LLVMTargetLibraryInfoRef = LLVMTargetLibraryInfo*;


extern(C):

//#--- Auto generated below ---#
enum LLVMByteOrdering {
	BigEndian = 0,
	LittleEndian = 1,
}
uint LLVMABIAlignmentOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);
ulong LLVMABISizeOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);
void LLVMAddTargetLibraryInfo(LLVMTargetLibraryInfoRef TLI, LLVMPassManagerRef PM);
LLVMByteOrdering LLVMByteOrder(LLVMTargetDataRef TD);
uint LLVMCallFrameAlignmentOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);
char* LLVMCopyStringRepOfTargetData(LLVMTargetDataRef TD);
LLVMTargetDataRef LLVMCreateTargetData(const(char)* StringRep);
void LLVMDisposeTargetData(LLVMTargetDataRef TD);
uint LLVMElementAtOffset(LLVMTargetDataRef TD, LLVMTypeRef StructTy, ulong Offset);
LLVMTargetDataRef LLVMGetModuleDataLayout(LLVMModuleRef M);
void LLVMInitializeAArch64AsmParser();
void LLVMInitializeAArch64AsmPrinter();
void LLVMInitializeAArch64Disassembler();
void LLVMInitializeAArch64Target();
void LLVMInitializeAArch64TargetInfo();
void LLVMInitializeAArch64TargetMC();
void LLVMInitializeARMAsmParser();
void LLVMInitializeARMAsmPrinter();
void LLVMInitializeARMDisassembler();
void LLVMInitializeARMTarget();
void LLVMInitializeARMTargetInfo();
void LLVMInitializeARMTargetMC();
void LLVMInitializeAllAsmParsers();
void LLVMInitializeAllAsmPrinters();
void LLVMInitializeAllDisassemblers();
void LLVMInitializeAllTargetInfos();
void LLVMInitializeAllTargetMCs();
void LLVMInitializeAllTargets();
LLVMBool LLVMInitializeNativeAsmParser();
LLVMBool LLVMInitializeNativeAsmPrinter();
LLVMBool LLVMInitializeNativeDisassembler();
LLVMBool LLVMInitializeNativeTarget();
void LLVMInitializeX86AsmParser();
void LLVMInitializeX86AsmPrinter();
void LLVMInitializeX86Disassembler();
void LLVMInitializeX86Target();
void LLVMInitializeX86TargetInfo();
void LLVMInitializeX86TargetMC();
LLVMTypeRef LLVMIntPtrType(LLVMTargetDataRef TD);
LLVMTypeRef LLVMIntPtrTypeForAS(LLVMTargetDataRef TD, uint AS);
LLVMTypeRef LLVMIntPtrTypeForASInContext(LLVMContextRef C, LLVMTargetDataRef TD, uint AS);
LLVMTypeRef LLVMIntPtrTypeInContext(LLVMContextRef C, LLVMTargetDataRef TD);
ulong LLVMOffsetOfElement(LLVMTargetDataRef TD, LLVMTypeRef StructTy, uint Element);
uint LLVMPointerSize(LLVMTargetDataRef TD);
uint LLVMPointerSizeForAS(LLVMTargetDataRef TD, uint AS);
uint LLVMPreferredAlignmentOfGlobal(LLVMTargetDataRef TD, LLVMValueRef GlobalVar);
uint LLVMPreferredAlignmentOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);
void LLVMSetModuleDataLayout(LLVMModuleRef M, LLVMTargetDataRef DL);
ulong LLVMSizeOfTypeInBits(LLVMTargetDataRef TD, LLVMTypeRef Ty);
ulong LLVMStoreSizeOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);
