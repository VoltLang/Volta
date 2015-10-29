/*===-- llvm-c/Target.h - Target Library C Interface --------------*- D -*-===*\
|*                                                                            *|
|*                     The LLVM Compiler Infrastructure                       *|
|*                                                                            *|
|* This file is distributed under the University of Illinois Open Source      *|
|* License. See src/lib/llvm/core.d for details.                              *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header declares the C interface to libLLVMTarget.a, which             *|
|* implements target information.                                             *|
|*                                                                            *|
|* Many exotic languages can interoperate with C code but have a harder time  *|
|* with C++ due to name mangling. So in addition to C, this interface enables *|
|* tools written in such languages.                                           *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* Up-to-date as of LLVM 3.4                                                  *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/
module lib.llvm.c.Target;

import lib.llvm.c.Core;


@loadDynamic extern(C):


/**
 * @defgroup LLVMCTarget Target information
 * @ingroup LLVMC
 *
 * @{
 */

enum LLVMByteOrdering
{
	BigEndian,
	LittleEndian
}

struct LLVMTargetData {}
alias  LLVMTargetDataRef = LLVMTargetData*;
struct LLVMTargetLibraryInfo {}
alias  LLVMTargetLibraryInfoRef = LLVMTargetLibraryInfo*;

/* A lot of targets are missing here but X86 is assumed safe */
void LLVMInitializeX86TargetInfo();
void LLVMInitializeX86Target();
void LLVMInitializeX86TargetMC();
void LLVMInitializeX86AsmPrinter();
void LLVMInitializeX86AsmParser();
void LLVMInitializeX86Disassembler();


/*===-- Target Data -------------------------------------------------------===*/

/** Creates target data from a target layout string.
    See the constructor llvm::DataLayout::DataLayout. */
LLVMTargetDataRef LLVMCreateTargetData(const(char)* StringRep);

/** Adds target data information to a pass manager. This does not take ownership
    of the target data.
    See the method llvm::PassManagerBase::add. */
void LLVMAddTargetData(LLVMTargetDataRef TD, LLVMPassManagerRef PM);

/** Adds target library information to a pass manager. This does not take
    ownership of the target library info.
    See the method llvm::PassManagerBase::add. */
void LLVMAddTargetLibraryInfo(LLVMTargetLibraryInfoRef TLI,
                              LLVMPassManagerRef PM);

/** Converts target data to a target layout string. The string must be disposed
    with LLVMDisposeMessage.
    See the constructor llvm::DataLayout::DataLayout. */
const(char)* LLVMCopyStringRepOfTargetData(LLVMTargetDataRef TD);

/** Returns the byte order of a target, either LLVMBigEndian or
    LLVMLittleEndian.
    See the method llvm::DataLayout::isLittleEndian. */
LLVMByteOrdering LLVMByteOrder(LLVMTargetDataRef TD);

/** Returns the pointer size in bytes for a target.
    See the method llvm::DataLayout::getPointerSize. */
uint LLVMPointerSize(LLVMTargetDataRef TD);

/** Returns the pointer size in bytes for a target for a specified
    address space.
    See the method llvm::DataLayout::getPointerSize. */
uint LLVMPointerSizeForAS(LLVMTargetDataRef TD, uint AS);

/** Returns the integer type that is the same size as a pointer on a target.
    See the method llvm::DataLayout::getIntPtrType. */
LLVMTypeRef LLVMIntPtrType(LLVMTargetDataRef TD);

/** Returns the integer type that is the same size as a pointer on a target.
    This version allows the address space to be specified.
    See the method llvm::DataLayout::getIntPtrType. */
LLVMTypeRef LLVMIntPtrTypeForAS(LLVMTargetDataRef TD, uint AS);

/** Returns the integer type that is the same size as a pointer on a target.
    See the method llvm::DataLayout::getIntPtrType. */
LLVMTypeRef LLVMIntPtrTypeInContext(LLVMContextRef C, LLVMTargetDataRef TD);

/** Returns the integer type that is the same size as a pointer on a target.
    This version allows the address space to be specified.
    See the method llvm::DataLayout::getIntPtrType. */
LLVMTypeRef LLVMIntPtrTypeForASInContext(LLVMContextRef C, LLVMTargetDataRef TD,
                                         uint AS);

/** Computes the size of a type in bytes for a target.
    See the method llvm::DataLayout::getTypeSizeInBits. */
ulong LLVMSizeOfTypeInBits(LLVMTargetDataRef TD, LLVMTypeRef Ty);

/** Computes the storage size of a type in bytes for a target.
    See the method llvm::DataLayout::getTypeStoreSize. */
ulong LLVMStoreSizeOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);

/** Computes the ABI size of a type in bytes for a target.
    See the method llvm::DataLayout::getTypeAllocSize. */
ulong LLVMABISizeOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);

/** Computes the ABI alignment of a type in bytes for a target.
    See the method llvm::DataLayout::getTypeABISize. */
uint LLVMABIAlignmentOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);

/** Computes the call frame alignment of a type in bytes for a target.
    See the method llvm::DataLayout::getTypeABISize. */
uint LLVMCallFrameAlignmentOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);

/** Computes the preferred alignment of a type in bytes for a target.
    See the method llvm::DataLayout::getTypeABISize. */
uint LLVMPreferredAlignmentOfType(LLVMTargetDataRef TD, LLVMTypeRef Ty);

/** Computes the preferred alignment of a global variable in bytes for a target.
    See the method llvm::DataLayout::getPreferredAlignment. */
uint LLVMPreferredAlignmentOfGlobal(LLVMTargetDataRef TD,
                                    LLVMValueRef GlobalVar);

/** Computes the structure element that contains the byte offset for a target.
    See the method llvm::StructLayout::getElementContainingOffset. */
uint LLVMElementAtOffset(LLVMTargetDataRef TD, LLVMTypeRef StructTy,
                         ulong Offset);

/** Computes the byte offset of the indexed struct element for a target.
    See the method llvm::StructLayout::getElementContainingOffset. */
ulong LLVMOffsetOfElement(LLVMTargetDataRef TD,
                          LLVMTypeRef StructTy, uint Element);

/** Deallocates a TargetData.
    See the destructor llvm::DataLayout::~DataLayout. */
void LLVMDisposeTargetData(LLVMTargetDataRef TD);

/**
 * @}
 */
