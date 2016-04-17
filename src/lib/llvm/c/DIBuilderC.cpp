//===-- DIBuilderC.cpp
//-------------------------------------------------------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements the the C binding for DIBuilder and some misc functions.
//
//===----------------------------------------------------------------------===//

#include "llvm-c/DIBuilder.h"

#include "llvm/IR/Module.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/DIBuilder.h"

#if LLVM_VERSION_MINOR < 8
#error "This version of LLVM is not supported"
#endif

#define DEFINE_MAV_WRAP(Type) \
inline LLVMValueRef wrap(Type *T) \
{ \
    if (T) \
      return wrap(MetadataAsValue::get(T->getContext(), T)); \
    return nullptr; \
}


using namespace llvm;

DEFINE_SIMPLE_CONVERSION_FUNCTIONS(DIBuilder, LLVMDIBuilderRef)

DEFINE_MAV_WRAP(DIFile)
DEFINE_MAV_WRAP(DILocation)
DEFINE_MAV_WRAP(DICompileUnit)
DEFINE_MAV_WRAP(DIEnumerator)
DEFINE_MAV_WRAP(DIBasicType)
DEFINE_MAV_WRAP(DIDerivedType)
DEFINE_MAV_WRAP(DIObjCProperty)
DEFINE_MAV_WRAP(DICompositeType)
DEFINE_MAV_WRAP(DITemplateValueParameter)
DEFINE_MAV_WRAP(DIGlobalVariable)
DEFINE_MAV_WRAP(DISubroutineType)
DEFINE_MAV_WRAP(DISubprogram)
DEFINE_MAV_WRAP(DISubrange)
DEFINE_MAV_WRAP(DIExpression)
DEFINE_MAV_WRAP(DILocalVariable)
DEFINE_MAV_WRAP(DILexicalBlockFile)
DEFINE_MAV_WRAP(DILexicalBlock)


inline Metadata *unwrapMD(LLVMValueRef Val)
{
  if (auto *V = unwrap(Val))
    if (auto *MDV = dyn_cast<MetadataAsValue>(V))
      return MDV->getMetadata();
  return nullptr;
}

template<class T> inline T* unwrapMDAs(LLVMValueRef V)
{
  return dyn_cast_or_null<T>(unwrapMD(V));
}


/*
 *
 * Misc functions.
 *
 */ 


unsigned LLVMGetDebugMetadataVersion()
{
  return DEBUG_METADATA_VERSION;
}

void LLVMBuilderAssociatePosition(LLVMBuilderRef builder, int Row, int Col,
                                  LLVMValueRef Scope) {
  auto S = unwrapMDAs<DIScope>(Scope);
  unwrap(builder)->SetCurrentDebugLocation(DebugLoc::get(Row, Col, S));
}

void LLVMBuilderDeassociatePosition(LLVMBuilderRef builder) {
  unwrap(builder)->SetCurrentDebugLocation(DebugLoc());
}


/*
 *
 * LLVMDIBuilder functions.
 *
 */


LLVMDIBuilderRef LLVMCreateDIBuilder(LLVMModuleRef module) {
  return wrap(new DIBuilder(*unwrap(module)));
}

void LLVMDisposeDIBuilder(LLVMDIBuilderRef builder) {
  delete unwrap(builder);
}

void LLVMDIBuilderFinalize(LLVMDIBuilderRef builder) {
  unwrap(builder)->finalize();
}

LLVMValueRef LLVMDIBuilderCreateCompileUnit(LLVMDIBuilderRef builder,
                                            unsigned Lang, const char *File,
                                            size_t FileLen, const char *Dir,
                                            size_t DirLen, const char *Producer,
                                            size_t ProducerLen,
                                            LLVMBool isOptimized,
                                            const char *Flags,
                                            size_t FlagsLen, unsigned RV,
                                            const char* SplitName,
                                            size_t SplitNameLen,
                                            LLVMDebugEmissionKind EmissionKind,
                                            uint64_t DWOiD,
                                            LLVMBool EmitDebugInfo) {

  DIBuilder::DebugEmissionKind Kind;
  switch (EmissionKind) {
  case LLVMDebugEmissionFull: Kind = DIBuilder::FullDebug; break;
  case LLVMDebugEmissionLineTablesOnly: Kind = DIBuilder::LineTablesOnly; break;
  default: assert(false && "Unkown emission type");
  }

  StringRef file(File, FileLen);
  StringRef dir(Dir, DirLen);
  StringRef producer(Producer, ProducerLen);
  StringRef flags(Flags, FlagsLen);
  StringRef split(SplitName, SplitNameLen);

  return wrap(unwrap(builder)
      ->createCompileUnit(Lang, file, dir, producer, isOptimized, flags, RV,
                          split, Kind, DWOiD, EmitDebugInfo));
}

LLVMValueRef LLVMDIBuilderCreateLocation(LLVMDIBuilderRef builder,
                                         unsigned Line, uint16_t Column,
                                         LLVMValueRef Scope) {

  auto S = unwrapMDAs<DIScope>(Scope);

  return wrap(DILocation::get(S->getContext(), Line, Column, S));
}

LLVMValueRef LLVMDIBuilderCreateFile(LLVMDIBuilderRef builder,
                                     const char *File, size_t FileLen,
                                     const char *Dir, size_t DirLen) {

  StringRef F(File, FileLen);
  StringRef D(Dir, DirLen);

  return wrap(unwrap(builder)->createFile(F, D));
}

LLVMValueRef LLVMDIBuilderCreateUnspecifiedType(LLVMDIBuilderRef builder,
                                                const char *Name,
                                                size_t NameLen) {

  StringRef N(Name, NameLen);
  auto B = unwrap(builder);
  return wrap(B->createUnspecifiedType(N));
}

LLVMValueRef LLVMDIBuilderCreateBasicType(LLVMDIBuilderRef builder,
                                          const char *Name, size_t NameLen,
                                          uint64_t sizeInBits,
                                          uint64_t alignInBits,
                                          unsigned Encoding) {

  StringRef name(Name, NameLen);

  return wrap(unwrap(builder)
                  ->createBasicType(name, sizeInBits, alignInBits, Encoding));
}

LLVMValueRef LLVMDIBuilderCreateQualifiedType(LLVMDIBuilderRef builder,
                                              unsigned Tag,
                                              LLVMValueRef FromTy) {
  auto T = unwrapMDAs<DIType>(FromTy);
  return wrap(unwrap(builder)->createQualifiedType(Tag, T));
}

LLVMValueRef LLVMDIBuilderCreatePointerType(LLVMDIBuilderRef builder,
                                            LLVMValueRef pointeeTy,
                                            uint64_t SizeInBits,
                                            uint64_t AlignInBits,
                                            const char *Name, size_t NameLen) {

  StringRef N(Name, NameLen);
  auto T = unwrapMDAs<DIType>(pointeeTy);

  return wrap(unwrap(builder)->createPointerType(
       T, SizeInBits, AlignInBits, N));
}

LLVMValueRef LLVMDIBuilderCreateMemberType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef File, unsigned LineNo, uint64_t SizeInBits,
    uint64_t AlignInBits, uint64_t OffsetInBits, unsigned Flags,
    LLVMValueRef Ty) {

  StringRef N(Name, NameLen);
  auto T = unwrapMDAs<DIType>(Ty);
  auto F = unwrapMDAs<DIFile>(File);
  auto S = unwrapMDAs<DIScope>(Scope);

  return wrap(unwrap(builder)->createMemberType(S, N, F, LineNo,
                                                SizeInBits, AlignInBits,
                                                OffsetInBits, Flags, T));
}

LLVMValueRef LLVMDIBuilderCreateStructType(LLVMDIBuilderRef builder,
                                           LLVMValueRef Scope, const char *Name,
                                           size_t NameLen, LLVMValueRef File,
                                           unsigned LineNumber,
                                           uint64_t SizeInBits,
                                           uint64_t AlignInBits, unsigned Flags,
                                           LLVMValueRef DerivedFrom,
                                           LLVMValueRef *Elements,
                                           size_t ElementsNum,
                                           LLVMValueRef VTableHolder,
                                           unsigned RunTimeLang,
                                           const char *UniqueIdentifier,
                                           size_t UniqueIdentifierLen) {

  StringRef N(Name, NameLen);
  StringRef UI(UniqueIdentifier, UniqueIdentifierLen);
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  auto DF = unwrapMDAs<DIType>(DerivedFrom);
  auto VTH = unwrapMDAs<DIType>(VTableHolder);

  SmallVector<Metadata *, 8> MDs;
  for (size_t i = 0; i < ElementsNum; i++) {
    auto *MD = unwrapMD(Elements[i]);
    MDs.push_back(MD);
  }

  return wrap(B->createStructType(
      S, N, F, LineNumber, SizeInBits, AlignInBits, Flags, DF,
      B->getOrCreateArray(MDs), RunTimeLang, VTH, UI));
}

LLVMValueRef LLVMDIBuilderCreateUnionType(LLVMDIBuilderRef builder,
                                          LLVMValueRef Scope, const char *Name,
                                          size_t NameLen, LLVMValueRef File,
                                          unsigned LineNumber,
                                          uint64_t SizeInBits,
                                          uint64_t AlignInBits, unsigned Flags,
                                          LLVMValueRef *Elements,
                                          size_t ElementsNum,
                                          unsigned RunTimeLang,
                                          const char *UniqueIdentifier,
                                          size_t UniqueIdentifierLen) {

  StringRef N(Name, NameLen);
  StringRef UI(UniqueIdentifier, UniqueIdentifierLen);
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);

  SmallVector<Metadata *, 8> MDs;
  for(size_t i = 0; i < ElementsNum; i++) {
    auto *MD = unwrapMD(Elements[i]);
    MDs.push_back(MD);
  }

  return wrap(B->createUnionType(
      S, N, F, LineNumber, SizeInBits, AlignInBits, Flags,
      B->getOrCreateArray(MDs), RunTimeLang, UI));
}

LLVMValueRef LLVMDIBuilderCreateArrayType(LLVMDIBuilderRef builder,
                                          uint64_t Size, uint64_t AlignInBits,
                                          LLVMValueRef Ty,
                                          LLVMValueRef *Subscripts,
                                          size_t SubscriptsNum) {

  auto B = unwrap(builder);
  auto T = unwrapMDAs<DIType>(Ty);

  SmallVector<Metadata *, 8> MDs;
  for(size_t i = 0; i < SubscriptsNum; i++) {
    auto *MD = unwrapMD(Subscripts[i]);
    MDs.push_back(MD);
  }

  return wrap(B->createArrayType(
      Size, AlignInBits, T, B->getOrCreateArray(MDs)));
}

LLVMValueRef LLVMDIBuilderCreateVectorType(LLVMDIBuilderRef builder,
                                           uint64_t Size, uint64_t AlignInBits,
                                           LLVMValueRef Ty,
                                           LLVMValueRef *Subscripts,
                                           size_t SubscriptsNum) {

  auto B = unwrap(builder);
  auto T = unwrapMDAs<DIType>(Ty);

  SmallVector<Metadata *, 8> MDs;
  for(size_t i = 0; i < SubscriptsNum; i++) {
    auto *MD = unwrapMD(Subscripts[i]);
    MDs.push_back(MD);
  }

  return wrap(B->createVectorType(
      Size, AlignInBits, T, B->getOrCreateArray(MDs)));
}

LLVMValueRef LLVMDIBuilderCreateSubroutineType(LLVMDIBuilderRef builder,
                                               LLVMValueRef File,
                                               LLVMValueRef *ParameterTypes,
                                               unsigned ParameterTypesNum,
                                               unsigned Flags) {

  auto B = unwrap(builder);
  // TODO auto F = unwrapMDAs<DIFile>(File);

  SmallVector<Metadata *, 8> MDs;
  for (size_t i = 0; i < ParameterTypesNum; i++) {
    auto *MD = unwrapMD(ParameterTypes[i]);
    MDs.push_back(MD);
  }

  return wrap(B->createSubroutineType(B->getOrCreateTypeArray(MDs), Flags));
}

void LLVMDIBuilderRetainType(LLVMDIBuilderRef builder, LLVMValueRef Ty) {
  auto T = unwrapMDAs<DIType>(Ty);
  unwrap(builder)->retainType(T);
}

LLVMValueRef LLVMDIBuilderCreateUnspecifiedParameter(LLVMDIBuilderRef builder) {
  return wrap(unwrap(builder)->createUnspecifiedParameter());
}

LLVMValueRef LLVMDIBuilderGetOrCreateRange(LLVMDIBuilderRef builder, int64_t Lo,
                                           int64_t Hi) {
  return wrap(unwrap(builder)->getOrCreateSubrange(Lo, Hi));
}

LLVMValueRef LLVMDIBuilderCreateGlobalVariable(LLVMDIBuilderRef builder,
                                               LLVMValueRef Scope,
                                               const char *Name, size_t NameLen,
                                               const char *LinkageName,
                                               size_t LinkageNameLen,
                                               LLVMValueRef File, uint LineNo,
                                               LLVMValueRef Ty,
                                               bool IsLocalToUnit,
                                               LLVMValueRef Val,
                                               LLVMValueRef Decl) {

  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  auto T = unwrapMDAs<DIType>(Ty);
  auto C = dyn_cast<Constant>(unwrap(Val));
  auto D = unwrapMDAs<MDNode>(Decl);

  return wrap(unwrap(builder)->createGlobalVariable(
      S, StringRef(Name, NameLen), StringRef(LinkageName, LinkageNameLen),
      F, LineNo, T, IsLocalToUnit, C, D));
}

LLVMValueRef LLVMDIBuilderCreateAutoVariable(LLVMDIBuilderRef builder,
                                             LLVMValueRef Scope,
                                             const char *Name,
                                             size_t NameLen, LLVMValueRef File,
                                             unsigned LineNo, LLVMValueRef Ty,
                                             bool AlwaysPreserve,
                                             unsigned Flags) {

  StringRef N(Name, NameLen);
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  auto T = unwrapMDAs<DIType>(Ty);

  return wrap(B->createAutoVariable(
      S, N, F, LineNo, T, AlwaysPreserve, Flags));
}

LLVMValueRef LLVMDIBuilderCreateParameterVariable(LLVMDIBuilderRef builder,
                                                  LLVMValueRef Scope,
                                                  const char *Name,
                                                  size_t NameLen,
                                                  unsigned ArgNo,
                                                  LLVMValueRef File,
                                                  unsigned LineNo,
                                                  LLVMValueRef Ty,
                                                  bool AlwaysPreserve,
                                                  unsigned Flags) {

  StringRef N(Name, NameLen);
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  auto T = unwrapMDAs<DIType>(Ty);

  return wrap(B->createParameterVariable(
      S, N, ArgNo, F, LineNo, T, AlwaysPreserve, Flags));
}

LLVMValueRef LLVMDIBuilderCreateFunction(LLVMDIBuilderRef builder,
                                         LLVMValueRef Scope,
                                         const char *Name, size_t NameLen,
                                         const char *LinkageName,
                                         size_t LinkageNameLen,
                                         LLVMValueRef File, unsigned LineNo,
                                         LLVMValueRef Ty, bool isLocalToUnit,
                                         bool isDefinition, unsigned ScopeLine,
                                         unsigned Flags, bool isOptimized,
                                         LLVMValueRef Fn, LLVMValueRef TParam,
                                         LLVMValueRef Decl) {
  StringRef N(Name, NameLen);
  StringRef LN(LinkageName, LinkageNameLen);
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  auto T = unwrapMDAs<DISubroutineType>(Ty);
  auto FN = dyn_cast<Function>(unwrap(Fn));
  // TODO auto TP = unwrapMDAs<MDNode>(TParam);
  auto D = unwrapMDAs<DISubprogram>(Decl);

  auto SUB = B->createFunction(S, N, LN, F, LineNo, T, isLocalToUnit,
      isDefinition, ScopeLine, Flags, isOptimized, nullptr, D);
  FN->setSubprogram(SUB);
  return wrap(SUB);
}

LLVMValueRef LLVMDIBuilderCreateLexicalBlockFile(LLVMDIBuilderRef builder,
                                                 LLVMValueRef Scope,
                                                 LLVMValueRef File,
                                                 unsigned Discriminator) {
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);

  return wrap(B->createLexicalBlockFile(S, F, Discriminator));
}

LLVMValueRef LLVMDIBuilderCreateLexicalBlock(LLVMDIBuilderRef builder,
                                             LLVMValueRef Scope,
                                             LLVMValueRef File, unsigned Line,
                                             unsigned Col) {

  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);

  return wrap(B->createLexicalBlock(S, F, Line, Col));
}

LLVMValueRef LLVMDIBuilderInsertDeclare(LLVMDIBuilderRef builder,
                                        LLVMValueRef Storage,
                                        LLVMValueRef ValInfo,
                                        LLVMValueRef Expr, LLVMValueRef DL,
                                        LLVMBasicBlockRef InsertAtEnd) {

  auto B = unwrap(builder);
  auto S = unwrap(Storage);
  auto V = unwrapMDAs<DILocalVariable>(ValInfo);
  auto E = unwrapMDAs<DIExpression>(Expr);
  auto D = unwrapMDAs<DILocation>(DL);
  auto IAE = unwrap(InsertAtEnd);

  return wrap(B->insertDeclare(S, V, E, D, IAE));
}

LLVMValueRef LLVMDIBuilderInsertDeclareBefore(LLVMDIBuilderRef builder,
                                              LLVMValueRef Storage,
                                              LLVMValueRef ValInfo,
                                              LLVMValueRef Expr,
                                              LLVMValueRef DL,
                                              LLVMValueRef InsertBefore) {

  auto B = unwrap(builder);
  auto S = unwrap(Storage);
  auto V = unwrapMDAs<DILocalVariable>(ValInfo);
  auto E = unwrapMDAs<DIExpression>(Expr);
  auto D = unwrapMDAs<DILocation>(DL);
  auto IB = unwrap<Instruction>(InsertBefore);

  return wrap(B->insertDeclare(S, V, E, D, IB));
}

LLVMValueRef LLVMDIBuilderCreateExpression(LLVMDIBuilderRef builder,
                                           uint64_t *Addr, size_t AddrNum) {

  auto B = unwrap(builder);
  SmallVector<uint64_t, 4> A;

  for (size_t i = 0; i < AddrNum; i++) {
    A.push_back(Addr[i]);
  }

  return wrap(B->createExpression(A));
}

void LLVMDIBuilderStructSetBody(LLVMDIBuilderRef builder, LLVMValueRef Struct,
                                LLVMValueRef *Elements, size_t ElementsNum) {

  auto B = unwrap(builder);
  auto fwd = unwrapMDAs<DICompositeType>(Struct);

  SmallVector<Metadata *, 8> MDs;
  for (size_t i = 0; i < ElementsNum; i++) {
    auto *MD = unwrapMD(Elements[i]);
    MDs.push_back(MD);
  }

  fwd->replaceElements(B->getOrCreateArray(MDs));
}

void LLVMDIBuilderUnionSetBody(LLVMDIBuilderRef builder, LLVMValueRef Union,
                               LLVMValueRef *Elements, size_t ElementsNum) {

  auto B = unwrap(builder);
  auto fwd = unwrapMDAs<DICompositeType>(Union);

  SmallVector<Metadata *, 8> MDs;
  for (size_t i = 0; i < ElementsNum; i++) {
    auto *MD = unwrapMD(Elements[i]);
    MDs.push_back(MD);
  }

  fwd->replaceElements(B->getOrCreateArray(MDs));
}
