/*===-- llvm-c/DIBuilder.h - Debug Info Builder C Interface -------*- C -*-===*\
|*                                                                            *|
|*                     The LLVM Compiler Infrastructure                       *|
|*                                                                            *|
|* This file is distributed under the University of Illinois Open Source      *|
|* License. See LICENSE.TXT for details.                                      *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header declares the C interface to DIBuilder in libLLVMCore.a, which  *|
|* implements the debug info creation.                                        *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/
module lib.llvm.c.DIBuilder;

import lib.llvm.c.Core;


extern(C):

uint LLVMGetDebugMetadataVersion();

void LLVMBuilderAssociatePosition(LLVMBuilderRef builder, int Row, int Col,
                                  LLVMValueRef Scope);
void LLVMBuilderDeassociatePosition(LLVMBuilderRef builder);


/**
 * @defgroup LLVMC DIBuilder: C interface to DIBuilder
 * @ingroup LLVMC
 *
 * @{
 */

enum LLVMDebugEmission {
  Full           = 1,
  LineTablesOnly = 2
}

struct LLVMDIBuilder {}
alias LLVMDIBuilderRef = LLVMDIBuilder*;

LLVMDIBuilderRef LLVMCreateDIBuilder(LLVMModuleRef mod);
void LLVMDisposeDIBuilder(LLVMDIBuilderRef builder);

LLVMValueRef LLVMDIBuilderGetCU(LLVMDIBuilderRef builder);

/**
 * Construct any deferred debug info descriptors.
 *
 * @see llvm::DIBuilder::finalize()
 */
void LLVMDIBuilderFinalize(LLVMDIBuilderRef builder);

/**
 * A CompileUnit provides an anchor for all debugging
 * information generated during this instance of compilation.
 *
 * @see llvm::DIBuilder::createCompileUnit()
 */
LLVMValueRef LLVMDIBuilderCreateCompileUnit(
    LLVMDIBuilderRef builder, uint Lang, const(char)* File, size_t FileLen,
    const(char)* Dir, size_t DirLen, const(char)* Producer, size_t ProducerLen,
    LLVMBool isOptimized, const(char)* Flags, size_t FlagsLen, uint RV,
    const char* SplitName, size_t SplitNameLen,
    LLVMDebugEmission EmissionKind, ulong DWOiD, LLVMBool EmitDebugInfo);

/**
 * Create a location descriptor to hold debugging information
 * for a location.
 *
 * @see llvm::DIBuilder::createLocation()
 */
LLVMValueRef LLVMDIBuilderCreateLocation(LLVMDIBuilderRef builder,
                                         uint Line, ushort Column,
                                         LLVMValueRef Scope);

/**
 * Create a file descriptor to hold debugging information
 * for a file.
 *
 * @see llvm::DIBuilder::createLocation()
 */
LLVMValueRef LLVMDIBuilderCreateFile(LLVMDIBuilderRef builder,
                                     const(char)* File, size_t FileLen,
                                     const(char)* Dir, size_t DirLen);


/**
 * Create a DWARF unspecified type.
 *
 * @see llvm::DIBuilder::createUnspecifiedType()
 */
LLVMValueRef LLVMDIBuilderCreateUnspecifiedType(
    LLVMDIBuilderRef builder, const(char)* Name, size_t NameLen);

/**
 * Create debugging information entry for a basic type.
 *
 * @see llvm::DIBuilder::createBasicType()
 */
LLVMValueRef LLVMDIBuilderCreateBasicType(LLVMDIBuilderRef builder,
                                          const(char)* Name, size_t NameLen,
                                          ulong sizeInBits,
                                          ulong alignInBits,
                                          uint Encoding);

/**
 * Create debugging information entry for a qualified
 * type, e.g. 'const int'.
 *
 * @see llvm::DIBuilder::createQualifiedType()
 */
LLVMValueRef LLVMDIBuilderCreateQualifiedType(LLVMDIBuilderRef builder,
                                              uint Tag,
                                              LLVMValueRef FromTy);

/**
 * Create debugging information entry for a pointer.
 *
 * @see llvm::DIBuilder::createPointerType()
 */
LLVMValueRef LLVMDIBuilderCreatePointerType(LLVMDIBuilderRef builder,
                                            LLVMValueRef pointeeTy,
                                            ulong SizeInBits,
                                            ulong AlignInBits,
                                            const(char)* Name, size_t NameLen);

/**
 * Create debugging information entry for a member.
 *
 * @see llvm::DIBuilder::createMemberType()
 */
LLVMValueRef LLVMDIBuilderCreateMemberType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const(char)* Name,
    size_t NameLen, LLVMValueRef File, uint LineNo, ulong SizeInBits,
    ulong AlignInBits, ulong OffsetInBits, uint Flags,
    LLVMValueRef Ty);

/**
 * Create debugging information entry for an union.
 *
 * @see llvm::DIBuilder::createUnionType()
 */
LLVMValueRef LLVMDIBuilderCreateStructType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const(char)* Name,
    size_t NameLen, LLVMValueRef File, uint LineNumber, ulong SizeInBits,
    ulong AlignInBits, uint Flags, LLVMValueRef DerivedFrom,
    LLVMValueRef *Elements, size_t ElementsNum,
    LLVMValueRef VTableHolder, uint RunTimeLang,
    const(char)* UniqueIdentifier, size_t UniqueIdentifierLen);

/**
 * Create debugging information entry for an union.
 *
 * @see llvm::DIBuilder::createUnionType()
 */
LLVMValueRef LLVMDIBuilderCreateUnionType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const(char)* Name,
    size_t NameLen, LLVMValueRef File, uint LineNumber, ulong SizeInBits,
    ulong AlignInBits, uint Flags, LLVMValueRef *Elements,
    size_t ElementsNum, uint RunTimeLang, const(char)* UniqueIdentifier,
    size_t UniqueIdentifierLen);

/**
 * Create debugging information entry for a array type.
 *
 * @see llvm::DIBuilder::createArrayType()
 */
LLVMValueRef LLVMDIBuilderCreateArrayType(
    LLVMDIBuilderRef builder, ulong Size, ulong AlignInBits,
    LLVMValueRef Ty, LLVMValueRef *Subscripts, size_t SubscriptsNum);

/**
 * Create debugging information entry for a vector type.
 *
 * @see llvm::DIBuilder::createVectorType()
 */
LLVMValueRef LLVMDIBuilderCreateVectorType(
    LLVMDIBuilderRef builder, ulong Size, ulong AlignInBits,
    LLVMValueRef Ty, LLVMValueRef *Subscripts, size_t SubscriptsNum);

/**
 * Create subroutine type.
 *
 * @see llvm::DIBuilder::createSubroutineType()
 */
LLVMValueRef LLVMDIBuilderCreateSubroutineType(LLVMDIBuilderRef builder,
                                               LLVMValueRef File,
                                               LLVMValueRef *ParameterTypes,
                                               uint ParameterTypesNum,
                                               uint Flags);

/**
 * Retain DIType* in a module even if it is not referenced
 * through debug info anchors.
 *
 * @see llvm::DIBuilder::retainType()
 */
void LLVMDIBuilderRetainType(LLVMDIBuilderRef builder, LLVMValueRef Ty);

/**
 * Create unspecified parameter type
 * for a subroutine type.
 *
 * @see llvm::DIBuilder::createUnspecifiedParameter()
 */
LLVMValueRef LLVMDIBuilderCreateUnspecifiedParameter(LLVMDIBuilderRef builder);

/**
 * Create a descriptor for a value range. This implicitly
 * uniques the values returned.
 *
 * @see llvm::DIBuilder::getOrCreateRange()
 */
LLVMValueRef LLVMDIBuilderGetOrCreateRange(LLVMDIBuilderRef builder, long Lo,
                                           long Count);

/**
 * Create a new descriptor for the specified variable.
 *
 * @see llvm::DIBuilder::createGlobalVariable()
 */
LLVMValueRef LLVMDIBuilderCreateGlobalVariable(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const(char)* Name,
    size_t NameLen, const(char)* LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, uint LineNo, LLVMValueRef Ty, bool IsLocalToUnit,
    LLVMValueRef Val, LLVMValueRef Decl);

/**
 * Create a new descriptor for an auto variable.  This is a local variable
 * that is not a subprogram parameter.
 *
 * @see llvm::DIBuilder::createAutoVariable()
 */
LLVMValueRef LLVMDIBuilderCreateAutoVariable(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const(char)* Name,
    size_t NameLen, LLVMValueRef File, uint LineNo,
    LLVMValueRef Ty, bool AlwaysPreserve, uint Flags);

/**
 * Create a new descriptor for a parameter variable.
 *
 * @see llvm::DIBuilder::createAutoVariable()
 */
LLVMValueRef LLVMDIBuilderCreateParameterVariable(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const(char)* Name,
    size_t NameLen, uint ArgNo, LLVMValueRef File, uint LineNo,
    LLVMValueRef Ty, bool AlwaysPreserve, uint Flags);

/**
 * Create a new descriptor for the specified subprogram.
 *
 * @see llvm::DIBuilder::createFunction()
 */
LLVMValueRef LLVMDIBuilderCreateFunction(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const(char)* Name,
    size_t NameLen, const(char)* LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, uint LineNo, LLVMValueRef Ty, bool isLocalToUnit,
    bool isDefinition, uint ScopeLine, uint Flags, bool isOptimized,
    LLVMValueRef Fn, LLVMValueRef TParam, LLVMValueRef Decl);

/**
 * This creates a descriptor for a lexical block
 * with a new file attached. This merely extends
 * the existing block.
 *
 * @see llvm::DIBuilder::createLexicalBlockFile()
 */
LLVMValueRef LLVMDIBuilderCreateLexicalBlockFile(LLVMDIBuilderRef builder,
                                                 LLVMValueRef Scope,
                                                 LLVMValueRef File,
                                                 uint Discriminator);

/**
 * This creates a descriptor for a lexical block
 * with the specified parent context.
 *
 * @see llvm::DIBuilder::createLexicalBlock()
 */
LLVMValueRef LLVMDIBuilderCreateLexicalBlock(LLVMDIBuilderRef builder,
                                             LLVMValueRef Scope,
                                             LLVMValueRef File, uint Line,
                                             uint Col);

/**
 * Insert a new llvm.dbg.declare intrinsic call.
 *
 * @see llvm::DIBuilder::insertDeclare()
 */
LLVMValueRef LLVMDIBuilderInsertDeclare(
    LLVMDIBuilderRef builder, LLVMValueRef Storage, LLVMValueRef ValInfo,
    LLVMValueRef Expr, LLVMValueRef DL, LLVMBasicBlockRef InsertAtEnd);

/**
 * Insert a new llvm.dbg.declare intrinsic call.
 *
 * @see llvm::DIBuilder::insertDeclare()
 */
LLVMValueRef LLVMDIBuilderInsertDeclareBefore(
    LLVMDIBuilderRef builder, LLVMValueRef Storage, LLVMValueRef ValInfo,
    LLVMValueRef Expr, LLVMValueRef DL, LLVMValueRef InsertBefore);

/**
 * Create a new descriptor for the specified
 * variable which has a complex address expression for its address.
 *
 * @see llvm::DIBuilder::insertDeclare()
 */
LLVMValueRef LLVMDIBuilderCreateExpression(
    LLVMDIBuilderRef builder, ulong *Addr, size_t AddrNum);

/**
 * Set the body of a struct debug info.
 */
void LLVMDIBuilderStructSetBody(LLVMDIBuilderRef builder,
                                LLVMValueRef Struct,
                                LLVMValueRef *Elements,
                                size_t ElementsNum);

/**
 * Set the body of a union debug info.
 */
void LLVMDIBuilderUnionSetBody(LLVMDIBuilderRef builder,
                                LLVMValueRef Struct,
                                LLVMValueRef *Elements,
                                size_t ElementsNum);

/**
 * @}
 */
