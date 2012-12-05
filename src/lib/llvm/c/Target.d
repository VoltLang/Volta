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
\*===----------------------------------------------------------------------===*/
module lib.llvm.c.Target;

import lib.llvm.c.Core;


extern(C):

enum LLVMByteOrdering { BigEndian, LittleEndian };

struct LLVMTargetData {}
alias  LLVMTargetData* LLVMTargetDataRef;
struct LLVMStructLayout {}
alias LLVMStructLayout* LLVMStructLayoutRef;

/* Declare all of the target-initialization functions that are available. */
/*
#define LLVM_TARGET(TargetName) void LLVMInitialize##TargetName##TargetInfo();
#include "llvm/Config/Targets.def"
#undef LLVM_TARGET  // Explicit undef to make SWIG happier

#define LLVM_TARGET(TargetName) void LLVMInitialize##TargetName##Target();
#include "llvm/Config/Targets.def"
#undef LLVM_TARGET  // Explicit undef to make SWIG happier
*/

/** LLVMInitializeAllTargetInfos - The main program should call this function if
    it wants access to all available targets that LLVM is configured to
    support. */
/*
static inline void LLVMInitializeAllTargetInfos() {
#define LLVM_TARGET(TargetName) LLVMInitialize##TargetName##TargetInfo();
#include "llvm/Config/Targets.def"
#undef LLVM_TARGET  // Explicit undef to make SWIG happier
}
*/

/** LLVMInitializeAllTargets - The main program should call this function if it
    wants to link in all available targets that LLVM is configured to
    support. */
/*
static inline void LLVMInitializeAllTargets() {
#define LLVM_TARGET(TargetName) LLVMInitialize##TargetName##Target();
#include "llvm/Config/Targets.def"
#undef LLVM_TARGET  // Explicit undef to make SWIG happier
}*/

/** LLVMInitializeNativeTarget - The main program should call this function to
    initialize the native target corresponding to the host.  This is useful
    for JIT applications to ensure that the target gets linked in correctly. */
/*
static inline LLVMBool LLVMInitializeNativeTarget() {
  // If we have a native target, initialize it to ensure it is linked in.
#ifdef LLVM_NATIVE_ARCH
#define DoInit2(TARG) \
  LLVMInitialize ## TARG ## Info ();          \
  LLVMInitialize ## TARG ()
#define DoInit(T) DoInit2(T)
  DoInit(LLVM_NATIVE_ARCH);
  return 0;
#undef DoInit
#undef DoInit2
#else
  return 1;
#endif
}
*/

/*===-- Target Data -------------------------------------------------------===*/

/** Creates target data from a target layout string.
    See the constructor llvm::TargetData::TargetData. */
LLVMTargetDataRef LLVMCreateTargetData(const(char)* StringRep);

/** Adds target data information to a pass manager. This does not take ownership
    of the target data.
    See the method llvm::PassManagerBase::add. */
void LLVMAddTargetData(LLVMTargetDataRef, LLVMPassManagerRef);

/** Converts target data to a target layout string. The string must be disposed
    with LLVMDisposeMessage.
    See the constructor llvm::TargetData::TargetData. */
char *LLVMCopyStringRepOfTargetData(LLVMTargetDataRef);

/** Returns the byte order of a target, either LLVMBigEndian or
    LLVMLittleEndian.
    See the method llvm::TargetData::isLittleEndian. */
LLVMByteOrdering LLVMByteOrder(LLVMTargetDataRef);

/** Returns the pointer size in bytes for a target.
    See the method llvm::TargetData::getPointerSize. */
uint LLVMPointerSize(LLVMTargetDataRef);

/** Returns the integer type that is the same size as a pointer on a target.
    See the method llvm::TargetData::getIntPtrType. */
LLVMTypeRef LLVMIntPtrType(LLVMTargetDataRef);

/** Computes the size of a type in bytes for a target.
    See the method llvm::TargetData::getTypeSizeInBits. */
ulong LLVMSizeOfTypeInBits(LLVMTargetDataRef, LLVMTypeRef);

/** Computes the storage size of a type in bytes for a target.
    See the method llvm::TargetData::getTypeStoreSize. */
ulong LLVMStoreSizeOfType(LLVMTargetDataRef, LLVMTypeRef);

/** Computes the ABI size of a type in bytes for a target.
    See the method llvm::TargetData::getTypeAllocSize. */
ulong LLVMABISizeOfType(LLVMTargetDataRef, LLVMTypeRef);

/** Computes the ABI alignment of a type in bytes for a target.
    See the method llvm::TargetData::getTypeABISize. */
uint LLVMABIAlignmentOfType(LLVMTargetDataRef, LLVMTypeRef);

/** Computes the call frame alignment of a type in bytes for a target.
    See the method llvm::TargetData::getTypeABISize. */
uint LLVMCallFrameAlignmentOfType(LLVMTargetDataRef, LLVMTypeRef);

/** Computes the preferred alignment of a type in bytes for a target.
    See the method llvm::TargetData::getTypeABISize. */
uint LLVMPreferredAlignmentOfType(LLVMTargetDataRef, LLVMTypeRef);

/** Computes the preferred alignment of a global variable in bytes for a target.
    See the method llvm::TargetData::getPreferredAlignment. */
uint LLVMPreferredAlignmentOfGlobal(LLVMTargetDataRef,
                                    LLVMValueRef GlobalVar);

/** Computes the structure element that contains the byte offset for a target.
    See the method llvm::StructLayout::getElementContainingOffset. */
uint LLVMElementAtOffset(LLVMTargetDataRef, LLVMTypeRef StructTy,
                         ulong Offset);

/** Computes the byte offset of the indexed struct element for a target.
    See the method llvm::StructLayout::getElementContainingOffset. */
ulong LLVMOffsetOfElement(LLVMTargetDataRef, LLVMTypeRef StructTy,
                          uint Element);

/** Struct layouts are speculatively cached. If a TargetDataRef is alive when
    types are being refined and removed, this method must be called whenever a
    struct type is removed to avoid a dangling pointer in this cache.
    See the method llvm::TargetData::InvalidateStructLayoutInfo. */
void LLVMInvalidateStructLayout(LLVMTargetDataRef, LLVMTypeRef StructTy);

/** Deallocates a TargetData.
    See the destructor llvm::TargetData::~TargetData. */
void LLVMDisposeTargetData(LLVMTargetDataRef);
