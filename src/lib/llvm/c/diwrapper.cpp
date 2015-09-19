/*===-- llvm-c/DIBuilder.h - Debug Info Builder C Interface -------*- C -*-===*\
|*                                                                            *|
|*                     The LLVM Compiler Infrastructure                       *|
|*                                                                            *|
|* This file is distributed under the University of Illinois Open Source      *|
|* License. See LICENSE.TXT for details.                                      *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header declares the C interface to libLLVMCore.a, which implements    *|
|* the LLVM intermediate representation.                                      *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

#ifndef LLVM_C_DIBUILDER_H
#define LLVM_C_DIBUILDER_H

#include "llvm/Support/DataTypes.h"

#ifdef __cplusplus

#include "llvm-c/Core.h"
#include "llvm-c/BitReader.h"
#include "llvm/IR/DebugInfo.h"
#include "llvm/IR/DIBuilder.h"


extern "C" {
#endif

/**
 * @defgroup LLVMC DIBuilder: C interface to DIBuilder
 * @ingroup LLVMC
 *
 * @{
 */

typedef enum {
  LLVMDebugEmissionFull           = 1,
  LLVMDebugEmissionLineTablesOnly = 2
} LLVMDebugEmissionKind;

typedef struct LLVMDIBuilder *LLVMDIBuilderRef;


LLVMDIBuilderRef LLVMCreateDIBuilder(LLVMModuleRef module);
void LLVMDisposeDIBuilder(LLVMDIBuilderRef builder);
LLVMValueRef LLVMDIBuilderGetCU(LLVMDIBuilderRef builder);
void LLVMDIBuilderFinalize(LLVMDIBuilderRef builder);
unsigned LLVMGetDebugMetadataVersion();


void LLVMBuilderAssociatePosition(LLVMBuilderRef builder, int Row, int Col,
                                  LLVMValueRef Scope);
void LLVMBuilderDeassociatePosition(LLVMBuilderRef builder);


/// A CompileUnit provides an anchor for all debugging
/// information generated during this instance of compilation.
/// \param Lang          Source programming language, eg. dwarf::DW_LANG_C99
/// \param File          File name
/// \param Dir           Directory
/// \param Producer      Identify the producer of debugging information
///                      and code.  Usually this is a compiler
///                      version string.
/// \param isOptimized   A boolean flag which indicates whether optimization
///                      is enabled or not.
/// \param Flags         This string lists command line options. This
///                      string is directly embedded in debug info
///                      output which may be used by a tool
///                      analyzing generated debugging information.
/// \param RV            This indicates runtime version for languages like
///                      Objective-C.
/// \param SplitName     The name of the file that we'll split debug info
///                      out into.
/// \param Kind          The kind of debug information to generate.
/// \param DWOId         The DWOId if this is a split skeleton compile unit.
/// \param EmitDebugInfo A boolean flag which indicates whether debug
///                      information should be written to the final output or
///                      not. When this is false, debug information annotations
///                      will be present in the IL but they are not written to
///                      the final assembly or object file. This supports
///                      tracking source location information in the back end
///                      without actually changing the output (e.g., when using
///                      optimization remarks).
LLVMValueRef LLVMDIBuilderCreateCompileUnit(
    LLVMDIBuilderRef builder, unsigned Lang, const char *File, size_t FileLen,
    const char *Dir, size_t DirLen, const char *Producer, size_t ProducerLen,
    LLVMBool isOptimized, const char *Flags, size_t FlagsLen, unsigned RV,
    const char* SplitName, size_t SplitNameLen,
    LLVMDebugEmissionKind EmissionKind, uint64_t DWOiD, LLVMBool EmitDebugInfo);

/// Create a file descriptor to hold debugging information
/// for a file.
LLVMValueRef LLVMDIBuilderCreateFile(LLVMDIBuilderRef builder,
                                     const char *File, size_t FileLen,
                                     const char *Dir, size_t DirLen);

/// Create a single enumerator value.
LLVMValueRef LLVMDIBuilderCreateEnumerator(LLVMDIBuilderRef builder,
                                           const char *Name, size_t NameLen,
                                           uint64_t Val);

/// Create a DWARF unspecified type.
LLVMValueRef LLVMDIBuilderCreateUnspecifiedType(
    LLVMDIBuilderRef builder, const char *Name, size_t NameLen);

/// createNullPtrType - Create C++0x nullptr type.
LLVMValueRef LLVMDIBuilderCreateNullPtr(LLVMDIBuilderRef builder);

/// Create debugging information entry for a basic
/// type.
/// \param Name        Type name.
/// \param SizeInBits  Size of the type.
/// \param AlignInBits Type alignment.
/// \param Encoding    DWARF encoding code, e.g. dwarf::DW_ATE_float.
LLVMValueRef LLVMDIBuilderCreateBasicType(LLVMDIBuilderRef builder,
                                          const char *Name, size_t NameLen,
                                          uint64_t sizeInBits,
                                          uint64_t alignInBits,
                                          unsigned Encoding);

/// Create debugging information entry for a qualified
/// type, e.g. 'const int'.
/// \param Tag         Tag identifing type, e.g. dwarf::TAG_volatile_type
/// \param FromTy      Base Type.
LLVMValueRef LLVMDIBuilderCreateQualifiedType(LLVMDIBuilderRef builder,
                                              unsigned Tag,
                                              LLVMValueRef FromTy);

/// Create debugging information entry for a qualified type, e.g. 'const int'.
/// \param Tag         Tag identifing type, e.g. dwarf::TAG_volatile_type
/// \param FromTy      Base Type.
LLVMValueRef LLVMDIBuilderCreatePointerType(LLVMDIBuilderRef builder,
                                            LLVMValueRef pointeeTy,
                                            uint64_t SizeInBits,
                                            uint64_t AlignInBits,
                                            const char *Name, size_t NameLen);

/// Create debugging information entry for a pointer to member.
/// \param PointeeTy Type pointed to by this pointer.
/// \param SizeInBits  Size.
/// \param AlignInBits Alignment. (optional)
/// \param Class Type for which this pointer points to members of.
LLVMValueRef LLVMDIBuilderCreateMemberPointerType(LLVMValueRef PointeeTy,
                                                  LLVMValueRef Class,
                                                  uint64_t SizeInBits,
                                                  uint64_t AlignInBits);

/// Create debugging information entry for a c++
/// style reference or rvalue reference type.
LLVMValueRef LLVMDIBuilderCreateReferenceType(LLVMDIBuilderRef builder,
                                              unsigned Tag, LLVMValueRef RTy);

/// Create debugging information entry for a typedef.
/// \param Ty          Original type.
/// \param Name        Typedef name.
/// \param File        File where this type is defined.
/// \param LineNo      Line number.
/// \param Context     The surrounding context for the typedef.
LLVMValueRef LLVMDIBuilderCreateTypedef(LLVMDIBuilderRef builder,
                                        LLVMValueRef Ty, const char *Name,
                                        size_t NameLen, LLVMValueRef File,
                                        unsigned LineNo, LLVMValueRef Context);

/// Create debugging information entry for a 'friend'.
LLVMValueRef LLVMDIBuilderCreateFriend(LLVMDIBuilderRef builder,
                                       LLVMValueRef Ty, LLVMValueRef FriendTy);

/// Create debugging information entry to establish
/// inheritance relationship between two types.
/// \param Ty           Original type.
/// \param BaseTy       Base type. Ty is inherits from base.
/// \param BaseOffset   Base offset.
/// \param Flags        Flags to describe inheritance attribute,
///                     e.g. private
LLVMValueRef LLVMDIBuilderCreateInheritence(LLVMDIBuilderRef builder,
                                            LLVMValueRef Ty,
                                            LLVMValueRef BaseTy,
                                            uint64_t BaseOffset,
                                            unsigned flags);

/// Create debugging information entry for a member.
/// \param Scope        Member scope.
/// \param Name         Member name.
/// \param File         File where this member is defined.
/// \param LineNo       Line number.
/// \param SizeInBits   Member size.
/// \param AlignInBits  Member alignment.
/// \param OffsetInBits Member offset.
/// \param Flags        Flags to encode member attribute, e.g. private
/// \param Ty           Parent type.
LLVMValueRef LLVMDIBuilderCreateMemberType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef File, unsigned LineNo, uint64_t SizeInBits,
    uint64_t AlignInBits, uint64_t OffsetInBits, unsigned Flags,
    LLVMValueRef Ty);

/// Create debugging information entry for a C++ static data member.
/// \param Scope      Member scope.
/// \param Name       Member name.
/// \param File       File where this member is declared.
/// \param LineNo     Line number.
/// \param Ty         Type of the static member.
/// \param Flags      Flags to encode member attribute, e.g. private.
/// \param Val        Const initializer of the member.
LLVMValueRef LLVMDIBuilderCreateStaticMemberType(
    LLVMValueRef Scope, const char *Name, size_t NameLen, LLVMValueRef File,
    unsigned LineNo, unsigned Flags, LLVMValueRef Val);

/// Create debugging information entry for Objective-C instance variable.
/// \param Name         Member name.
/// \param File         File where this member is defined.
/// \param LineNo       Line number.
/// \param SizeInBits   Member size.
/// \param AlignInBits  Member alignment.
/// \param OffsetInBits Member offset.
/// \param Flags        Flags to encode member attribute, e.g. private
/// \param Ty           Parent type.
/// \param PropertyNode Property associated with this ivar.
LLVMValueRef LLVMDIBuilderCreateObjCIVar(
    LLVMDIBuilderRef builder, const char *Name, size_t NameLen,
    LLVMValueRef File, unsigned LineNo, uint64_t SizeInBits,
    uint64_t AlignInBits, uint64_t OffsetInBits, unsigned Flags,
    LLVMValueRef Ty, LLVMValueRef PropertyNode);

/// Create debugging information entry for Objective-C
/// instance variable.
/// \param Name         Member name.
/// \param File         File where this member is defined.
/// \param LineNo       Line number.
/// \param SizeInBits   Member size.
/// \param AlignInBits  Member alignment.
/// \param OffsetInBits Member offset.
/// \param Flags        Flags to encode member attribute, e.g. private
/// \param Ty           Parent type.
/// \param PropertyNode Property associated with this ivar.
LLVMValueRef LLVMDIBuilderCreateObjCProperty(
    LLVMDIBuilderRef builder, const char *Name, size_t NameLen,
    LLVMValueRef File, unsigned LineNumber, const char *GetterName,
    size_t GetterNameLen, const char *SetterName, size_t SetterNameLen,
    unsigned PropertyAttributes, LLVMValueRef Ty);

/// Create debugging information entry for a class.
/// \param Scope        Scope in which this class is defined.
/// \param Name         class name.
/// \param File         File where this member is defined.
/// \param LineNumber   Line number.
/// \param SizeInBits   Member size.
/// \param AlignInBits  Member alignment.
/// \param OffsetInBits Member offset.
/// \param Flags        Flags to encode member attribute, e.g. private
/// \param Elements     class members.
/// \param VTableHolder Debug info of the base class that contains vtable
///                     for this type. This is used in
///                     DW_AT_containing_type. See DWARF documentation
///                     for more info.
/// \param TemplateParms Template type parameters.
/// \param UniqueIdentifier A unique identifier for the class.
LLVMValueRef LLVMDIBuilderCreateClassType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef File, unsigned LineNumber, uint64_t SizeInBits,
    uint64_t AlignInBits, uint64_t OffsetInBits, unsigned Flags,
    LLVMValueRef DerivedFrom, LLVMValueRef *Elements, size_t ElementsNum,
    LLVMValueRef VTableHolder, LLVMValueRef TemplateParms,
    const char *UniqueIdentifier, size_t UniqueIdentifierLen);

/// Create debugging information entry for a struct.
/// \param Scope        Scope in which this struct is defined.
/// \param Name         Struct name.
/// \param File         File where this member is defined.
/// \param LineNumber   Line number.
/// \param SizeInBits   Member size.
/// \param AlignInBits  Member alignment.
/// \param Flags        Flags to encode member attribute, e.g. private
/// \param Elements     Struct elements.
/// \param RunTimeLang  Optional parameter, Objective-C runtime version.
/// \param UniqueIdentifier A unique identifier for the struct.
LLVMValueRef LLVMDIBuilderCreateStructType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef File, unsigned LineNumber, uint64_t SizeInBits,
    uint64_t AlignInBits, unsigned Flags, LLVMValueRef DerivedFrom,
    LLVMValueRef *Elements, size_t ElementsNum,
    LLVMValueRef VTableHolder, unsigned RunTimeLang,
    const char *UniqueIdentifier, size_t UniqueIdentifierLen);

/// Create debugging information entry for an union.
/// \param Scope        Scope in which this union is defined.
/// \param Name         Union name.
/// \param File         File where this member is defined.
/// \param LineNumber   Line number.
/// \param SizeInBits   Member size.
/// \param AlignInBits  Member alignment.
/// \param Flags        Flags to encode member attribute, e.g. private
/// \param Elements     Union elements.
/// \param RunTimeLang  Optional parameter, Objective-C runtime version.
/// \param UniqueIdentifier A unique identifier for the union.
LLVMValueRef LLVMDIBuilderCreateUnionType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef File, unsigned LineNumber, uint64_t SizeInBits,
    uint64_t AlignInBits, unsigned Flags, LLVMValueRef *Elements,
    size_t ElementsNum, unsigned RunTimeLang, const char *UniqueIdentifier,
    size_t UniqueIdentifierLen);

/// Create debugging information for template type parameter.
/// \param Scope        Scope in which this type is defined.
/// \param Name         Type parameter name.
/// \param Ty           Parameter type.
LLVMValueRef LLVMDIBuilderCreateTemplateTypeParameter(LLVMDIBuilderRef builder,
    LLVMValueRef Scope, const char *Name, size_t NameLen, LLVMValueRef Ty);

/// createTemplateValueParameter - Create debugging information for template
/// value parameter.
/// @param Scope        Scope in which this type is defined.
/// @param Name         Value parameter name.
/// @param Ty           Parameter type.
/// @param Constant     Value as a Constant.
LLVMValueRef LLVMDIBuilderCreateTemplateValueParameter(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef Ty, LLVMValueRef ConstantV);

/// Create debugging information for template
/// type parameter.
/// \param Scope        Scope in which this type is defined.
/// \param Name         Type parameter name.
/// \param Ty           Parameter type.
LLVMValueRef LLVMDIBuilderCreateTemplateTemplateParameter(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef Ty, const char *Val, size_t ValLen);

/// Create debugging information for a template parameter pack.
/// \param Scope        Scope in which this type is defined.
/// \param Name         Value parameter name.
/// \param Ty           Parameter type.
/// \param Val          An array of types in the pack.
LLVMValueRef LLVMDIBuilderCreateTemplatePackParameter(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef Ty, LLVMValueRef *Val, unsigned ValCount);

/// Create debugging information entry for an array.
/// \param Size         Array size.
/// \param AlignInBits  Alignment.
/// \param Ty           Element type.
/// \param Subscripts   Subscripts.
LLVMValueRef LLVMDIBuilderCreateArrayType(
    LLVMDIBuilderRef builder, uint64_t Size, uint64_t AlignInBits,
    LLVMValueRef Ty, LLVMValueRef *Subscripts, size_t SubscriptsNum);

/// Create debugging information entry for a vector type.
/// \param Size         Array size.
/// \param AlignInBits  Alignment.
/// \param Ty           Element type.
/// \param Subscripts   Subscripts.
LLVMValueRef LLVMDIBuilderCreateVectorType(
    LLVMDIBuilderRef builder, uint64_t Size, uint64_t AlignInBits,
    LLVMValueRef Ty, LLVMValueRef *Subscripts, size_t SubscriptsNum);

/// Create debugging information entry for an
/// enumeration.
/// \param Scope          Scope in which this enumeration is defined.
/// \param Name           Union name.
/// \param File           File where this member is defined.
/// \param LineNumber     Line number.
/// \param SizeInBits     Member size.
/// \param AlignInBits    Member alignment.
/// \param Elements       Enumeration elements.
/// \param UnderlyingType Underlying type of a C++11/ObjC fixed enum.
/// \param UniqueIdentifier A unique identifier for the enum.
LLVMValueRef LLVMDIBuilderCreateEnumerationType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef File, unsigned LineNumber,
    uint64_t SizeInBits, uint64_t AlignInBits,
    LLVMValueRef Elements, size_t ElementsNum, LLVMValueRef UnderlyingType,
    const char *UniqueIdentifier, size_t UniqueIdentifierLen);

/// Create subroutine type.
/// \param File            File in which this subroutine is defined.
/// \param ParameterTypes  An array of subroutine parameter types. This
///                        includes return type at 0th index.
/// \param Flags           E.g.: LValueReference.
///                        These flags are used to emit dwarf attributes.
LLVMValueRef LLVMDIBuilderCreateSubroutineType(LLVMDIBuilderRef builder,
                                               LLVMValueRef File,
                                               LLVMValueRef *ParameterTypes,
                                               unsigned ParameterTypesNum,
                                               unsigned Flags);

/// Create an external type reference.
/// \param Tag              Dwarf TAG.
/// \param File             File in which the type is defined.
/// \param UniqueIdentifier A unique identifier for the type.
LLVMValueRef LLVMDIBuilderCreateExternalTypeRef(
    LLVMDIBuilder builder, unsigned Tag, LLVMValueRef File,
    const char *UniqueIdentifier, size_t UniqueIdentifierLen);

/// Create a new DIType with "artificial" flag set.
LLVMValueRef LLVMDIBuilderCreateArtificialType(LLVMDIBuilderRef builder,
                                               LLVMValueRef Ty);

/// Create a new DIType* with the "object pointer"
/// flag set.
LLVMValueRef LLVMDIBuilderCreateObjectPointerType(LLVMDIBuilderRef builder,
                                                  LLVMValueRef Ty);

/// Create a permanent forward-declared type.
LLVMValueRef LLVMDIBuilderCreateForwardDecl(
    LLVMDIBuilderRef builder, unsigned Tag, const char *Name, size_t NameLen,
    LLVMValueRef Scope, LLVMValueRef File, unsigned Line, unsigned RuntimeLang,
    uint64_t SizeInBits, uint64_t AlignInBits,
    const char *UniqueIdentifier, size_t UniqueIdentifierLen);

/// Create a temporary forward-declared type.
LLVMValueRef LLVMDIBuilderCreateReplaceableCompositeType(
    LLVMDIBuilderRef builder, unsigned Tag, const char *Name, size_t NameLen,
    LLVMValueRef Scope, LLVMValueRef File, unsigned Line, unsigned RuntimeLang,
    uint64_t SizeInBits, uint64_t AlignInBits, unsigned Flags,
    const char *UniqueIdentifier, size_t UniqueIdentifierLen);

/// Retain DIType* in a module even if it is not referenced
/// through debug info anchors.
void LLVMDIBuilderRetainType(LLVMDIBuilderRef builder, LLVMValueRef Ty);

/// Create unspecified parameter type
/// for a subroutine type.
LLVMValueRef LLVMDIBuilderCreateUnspecifiedParameter(LLVMDIBuilderRef builder);

/// getOrCreateSubrange - Create a descriptor for a value range.  This
/// implicitly uniques the values returned.
LLVMValueRef LLVMDIBuilderGetOrCreateRange(LLVMDIBuilderRef builder, int64_t Lo,
                                           int64_t Count);

/// Create a new descriptor for the specified
/// variable.
/// \param Context     Variable scope.
/// \param Name        Name of the variable.
/// \param LinkageName Mangled  name of the variable.
/// \param File        File where this variable is defined.
/// \param LineNo      Line number.
/// \param Ty          Variable Type.
/// \param isLocalToUnit Boolean flag indicate whether this variable is
///                      externally visible or not.
/// \param Val         llvm::Value of the variable.
/// \param Decl        Reference to the corresponding declaration.
LLVMValueRef LLVMDIBuilderCreateGlobalVariable(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, const char *LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, uint LineNo, LLVMValueRef Ty, bool IsLocalToUnit,
    LLVMValueRef Val, LLVMValueRef Decl);

/// Identical to createGlobalVariable
/// except that the resulting DbgNode is temporary and meant to be RAUWed.
LLVMValueRef LLVMDIBuilderCreateTempGlobalVariableFwdDecl(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, const char *LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, uint LineNo, LLVMValueRef Ty, bool IsLocalToUnit,
    LLVMValueRef Val, LLVMValueRef Decl);

/// Create a new descriptor for the specified subprogram.
/// See comments in DISubprogram* for descriptions of these fields.
/// \param Scope         Function scope.
/// \param Name          Function name.
/// \param LinkageName   Mangled function name.
/// \param File          File where this variable is defined.
/// \param LineNo        Line number.
/// \param Ty            Function type.
/// \param isLocalToUnit True if this function is not externally visible.
/// \param isDefinition  True if this is a function definition.
/// \param ScopeLine     Set to the beginning of the scope this starts
/// \param Flags         e.g. is this function prototyped or not.
///                      These flags are used to emit dwarf attributes.
/// \param isOptimized   True if optimization is ON.
/// \param Fn            llvm::Function pointer.
/// \param TParam        Function template parameters.
LLVMValueRef LLVMDIBuilderCreateFunction(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, const char *LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, unsigned LineNo, LLVMValueRef Ty, bool isLocalToUnit,
    bool isDefinition, unsigned ScopeLine, unsigned Flags, bool isOptimized,
    LLVMValueRef Fn, LLVMValueRef TParam, LLVMValueRef Decl);

/// Identical to createFunction,
/// except that the resulting DbgNode is meant to be RAUWed.
LLVMValueRef LLVMDIBuilderCreateTempFunctionFwdDecl(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, const char *LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, unsigned LineNo, LLVMValueRef Ty, bool isLocalToUnit,
    bool isDefinition, unsigned ScopeLine, unsigned Flags, bool isOptimized,
    LLVMValueRef Fn, LLVMValueRef TParam, LLVMValueRef Decl);

/// Create a new descriptor for the specified C++ method.
/// See comments in \a DISubprogram* for descriptions of these fields.
/// \param Scope         Function scope.
/// \param Name          Function name.
/// \param LinkageName   Mangled function name.
/// \param File          File where this variable is defined.
/// \param LineNo        Line number.
/// \param Ty            Function type.
/// \param isLocalToUnit True if this function is not externally visible..
/// \param isDefinition  True if this is a function definition.
/// \param Virtuality    Attributes describing virtualness. e.g. pure
///                      virtual function.
/// \param VTableIndex   Index no of this method in virtual table.
/// \param VTableHolder  Type that holds vtable.
/// \param Flags         e.g. is this function prototyped or not.
///                      This flags are used to emit dwarf attributes.
/// \param isOptimized   True if optimization is ON.
/// \param Fn            llvm::Function pointer.
/// \param TParam        Function template parameters.
LLVMValueRef LLVMDIBuilderCreateMethod(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, const char *LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, unsigned LineNo, LLVMValueRef Ty, bool isLocalToUnit,
    bool isDefintiion, unsigned Virtuality, unsigned VTableIndex,
    LLVMValueRef VTableHolder, unsigned Flags, bool isOptimized,
    LLVMValueRef Fn, LLVMValueRef TParam);

/// This creates new descriptor for a namespace with the specified
/// parent scope.
/// \param Scope       Namespace scope
/// \param Name        Name of this namespace
/// \param File        Source file
/// \param LineNo      Line number
LLVMValueRef LLVMDIBuilderCreateNameSpace(LLVMDIBuilderRef builder,
                                          LLVMValueRef Scope, const char *Name,
                                          size_t NameLen, LLVMValueRef File,
                                          unsigned LineNo);

/// This creates new descriptor for a module with the specified
/// parent scope.
/// \param Scope       Parent scope
/// \param Name        Name of this module
/// \param ConfigurationMacros
///                    A space-separated shell-quoted list of -D macro
///                    definitions as they would appear on a command line.
/// \param IncludePath The path to the module map file.
/// \param ISysRoot    The clang system root (value of -isysroot).
LLVMValueRef LLVMDIBuilderCreateModule(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name, 
    size_t NameLen, const char *ConfigurationMacros,
    size_t ConfigurationMacrosLen, const char *IncludePath,
    size_t IncludePathLen, const char *ISysRoot, size_t ISysRootLen);

/// This creates a descriptor for a lexical block with a new file
/// attached. This merely extends the existing
/// lexical block as it crosses a file.
/// \param Scope       Lexical block.
/// \param File        Source file.
/// \param Discriminator DWARF path discriminator value.
LLVMValueRef LLVMDIBuilderCreateLexicalBlockFile(LLVMDIBuilderRef builder,
                                                 LLVMValueRef Scope,
                                                 LLVMValueRef File,
                                                 unsigned Discriminator);

/// createLexicalBlock - This creates a descriptor for a lexical block
/// with the specified parent context.
/// @param Scope       Parent lexical scope.
/// @param File        Source file
/// @param Line        Line number
/// @param Col         Column number
LLVMValueRef LLVMDIBuilderCreateLexicalBlock(LLVMDIBuilderRef builder,
                                             LLVMValueRef Scope,
                                             LLVMValueRef File, unsigned Line,
                                             unsigned Col);

/// Create a descriptor for an imported module.
/// \param Context The scope this module is imported into
/// \param NSOrM The namespace or module being imported here
/// \param Line Line number
LLVMValueRef LLVMDIBuilderCreateImportedModule(LLVMDIBuilderRef builder,
                                               LLVMValueRef Context,
                                               LLVMValueRef NSOrM,
                                               unsigned Line);

/// Create a descriptor for an imported function.
/// \param Context The scope this module is imported into
/// \param Decl The declaration (or definition) of a function, type, or
///             variable
/// \param Line Line number
LLVMValueRef LLVMDIBuilderCreateImportedDeclaration(
    LLVMDIBuilderRef builder, LLVMValueRef Context, LLVMValueRef Decl,
    unsigned Line, const char *Name, size_t NameLen);

/// Insert a new llvm.dbg.declare intrinsic call.
/// \param Storage     llvm::Value of the variable
/// \param VarInfo     Variable's debug info descriptor.
/// \param Expr        A complex location expression.
/// \param DL          Debug info location.
/// \param InsertAtEnd Location for the new intrinsic.
LLVMValueRef LLVMDIBuilderInsertDeclare(
    LLVMDIBuilderRef builder, LLVMValueRef ValInfo, LLVMValueRef Expr,
    LLVMValueRef DL, LLVMBasicBlockRef InsertAtEnd);

/// Insert a new llvm.dbg.declare intrinsic call.
/// \param Storage      llvm::Value of the variable
/// \param VarInfo      Variable's debug info descriptor.
/// \param Expr         A complex location expression.
/// \param DL           Debug info location.
/// \param InsertBefore Location for the new intrinsic.
LLVMValueRef LLVMDIBuilderInsertDeclareBefore(
    LLVMDIBuilderRef builder, LLVMValueRef ValInfo, LLVMValueRef Expr,
    LLVMValueRef DL, LLVMValueRef InsertBefore);

/// insertDbgValueIntrinsic - Insert a new llvm.dbg.value intrinsic call.
/// @param Val          llvm::Value of the variable
/// @param Offset       Offset
/// @param VarInfo      Variable's debug info descriptor.
/// @param InsertAtEnd Location for the new intrinsic.
LLVMValueRef LLVMDIBuilderInsertDgbValueInstrinsic(
    LLVMDIBuilderRef builder, LLVMValueRef Val, uint64_t Offset,
    LLVMValueRef VarInfo, LLVMBasicBlockRef InsertAtEnd);

/// Insert a new llvm.dbg.value intrinsic call.
/// \param Val          llvm::Value of the variable
/// \param Offset       Offset
/// \param VarInfo      Variable's debug info descriptor.
/// \param Expr         A complex location expression.
/// \param DL           Debug info location.
/// \param InsertBefore Location for the new intrinsic.
LLVMValueRef LLVMDIBuilderInsertDbgValueIntrinsicBefore(
    LLVMDIBuilderRef builder, LLVMValueRef Val, uint64_t Offset,
    LLVMValueRef VarInfo, LLVMValueRef InsertBefore);

void LLVMDIBuilderStructSetBody(LLVMDIBuilderRef builder,
                                LLVMValueRef Struct,
                                LLVMValueRef *Elements,
                                size_t ElementsNum);

#ifdef __cplusplus
}
#endif /* !defined(__cplusplus) */

#endif /* !LLVM_C_DIBUILDER_H */


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
// This file implements the the C binding for DIBuilder
//
//===----------------------------------------------------------------------===//

#include "llvm-c/Core.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/IRBuilder.h"

#include "llvm/Object/ObjectFile.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/IR/DiagnosticPrinter.h"

#include "llvm/IR/CallSite.h"

using namespace llvm;

DEFINE_SIMPLE_CONVERSION_FUNCTIONS(DIBuilder, LLVMDIBuilderRef)

#if LLVM_VERSION_MINOR >= 7
#define DEFINE_MAV_WRAP(Type) \
inline LLVMValueRef wrap(Type *T) \
{ \
    if (T) \
      return wrap(MetadataAsValue::get(T->getContext(), T)); \
    return nullptr; \
}
#elif LLVM_VERSION_MINOR <= 6
#define DEFINE_MAV_WRAP(Type) \
inline LLVMValueRef wrap(Type T) \
{ \
    if (T) \
      return wrap(MetadataAsValue::get(T->getContext(), T)); \
    return nullptr; \
}
#else
#error "This version of LLVM is not supported"
#endif

DEFINE_MAV_WRAP(DIFile)
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

inline Metadata *unwrapMD(LLVMValueRef Val)
{
  if (auto *V = unwrap(Val))
    if (auto *MDV = dyn_cast<MetadataAsValue>(V))
      return MDV->getMetadata();
  return nullptr;
}

#if LLVM_VERSION_MINOR >= 7
template<class T> inline T* unwrapMDAs(LLVMValueRef V)
{
  return dyn_cast_or_null<T>(unwrapMD(V));
}
#elif LLVM_VERSION_MINOR == 6
template<class T> inline T unwrapMDAs(LLVMValueRef V)
{
  return T((MDNode*)unwrapMD(V));
}
#else
#error "This version of LLVM is not supported"
#endif


#define XXX_TODO_TEST_ME_XXX() \
  do { assert(0 && "TEST ME"); *(int*)nullptr = 0; } while(false)


/*
 *
 * LLVMBuilder functions.
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
  Module *mod = unwrap(module);
  return wrap(new DIBuilder(*mod));
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
                          split, Kind,
#if LLVM_VERSION_MINOR >= 7
                          DWOiD,
#endif
                          EmitDebugInfo));
}

LLVMValueRef LLVMDIBuilderCreateFile(LLVMDIBuilderRef builder,
                                     const char *File, size_t FileLen,
                                     const char *Dir, size_t DirLen) {
  StringRef F(File, FileLen);
  StringRef D(Dir, DirLen);
  return wrap(unwrap(builder)->createFile(F, D));
}

LLVMValueRef LLVMDIBuilderCreateUnspecifiedType(
    LLVMDIBuilderRef builder, const char *Name, size_t NameLen) {
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

LLVMValueRef LLVMDIBuilderCreateStructType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef File, unsigned LineNumber, uint64_t SizeInBits,
    uint64_t AlignInBits, unsigned Flags, LLVMValueRef DerivedFrom,
    LLVMValueRef *Elements, size_t ElementsNum,
    LLVMValueRef VTableHolder, unsigned RunTimeLang,
    const char *UniqueIdentifier, size_t UniqueIdentifierLen) {

  StringRef N(Name, NameLen);
  StringRef UI(UniqueIdentifier, UniqueIdentifierLen);
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  auto DF = unwrapMDAs<DIType>(DerivedFrom);
  auto VTH = unwrapMDAs<DIType>(VTableHolder);

  SmallVector<Metadata *, 8> MDs;
  for (int i = 0; i < ElementsNum; i++) {
    auto *MD = unwrapMD(Elements[i]);
    // TODO Extract?
    MDs.push_back(MD);
  }

  return wrap(B->createStructType(
      S, N, F, LineNumber, SizeInBits, AlignInBits, Flags, DF,
      B->getOrCreateArray(MDs), RunTimeLang, VTH, UI));
}

LLVMValueRef LLVMDIBuilderCreateUnionType(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, LLVMValueRef File, unsigned LineNumber, uint64_t SizeInBits,
    uint64_t AlignInBits, unsigned Flags, LLVMValueRef *Elements,
    size_t ElementsNum, unsigned RunTimeLang, const char *UniqueIdentifier,
    size_t UniqueIdentifierLen) {

  StringRef N(Name, NameLen);
  StringRef UI(UniqueIdentifier, UniqueIdentifierLen);
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  SmallVector<Metadata *, 8> MDs;
  for(int i = 0; i < ElementsNum; i++) {
    auto *MD = unwrapMD(Elements[i]);
    // TODO Extract?
    MDs.push_back(MD);
  }
  return wrap(B->createUnionType(
      S, N, F, LineNumber, SizeInBits, AlignInBits, Flags,
      B->getOrCreateArray(MDs), RunTimeLang, UI));
}

LLVMValueRef LLVMDIBuilderCreateArrayType(
    LLVMDIBuilderRef builder, uint64_t Size, uint64_t AlignInBits,
    LLVMValueRef Ty, LLVMValueRef *Subscripts, size_t SubscriptsNum) {

  auto B = unwrap(builder);
  auto T = unwrapMDAs<DIType>(Ty);
  SmallVector<Metadata *, 8> MDs;
  for(int i = 0; i < SubscriptsNum; i++) {
    auto *MD = unwrapMD(Subscripts[i]);
    // TODO Extract?
    MDs.push_back(MD);
  }
  return wrap(B->createArrayType(
      Size, AlignInBits, T, B->getOrCreateArray(MDs)));
}

LLVMValueRef LLVMDIBuilderCreateSubroutineType(LLVMDIBuilderRef builder,
                                               LLVMValueRef File,
                                               LLVMValueRef *ParameterTypes,
                                               unsigned ParameterTypesNum,
                                               unsigned Flags) {
  auto B = unwrap(builder);
  auto F = unwrapMDAs<DIFile>(File);

  SmallVector<Metadata *, 8> MDs;
  for (int i = 0; i < ParameterTypesNum; i++) {
    auto *MD = unwrapMD(ParameterTypes[i]);
    // TODO Extract?
    MDs.push_back(MD);
  }

  return wrap(B->createSubroutineType(F, B->getOrCreateTypeArray(MDs), Flags));
}

LLVMValueRef LLVMDIBuilderGetOrCreateRange(LLVMDIBuilderRef builder, int64_t Lo,
                                           int64_t Hi) {
  return wrap(unwrap(builder)->getOrCreateSubrange(Lo, Hi));
}

LLVMValueRef LLVMDIBuilderCreateGlobalVariable(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, const char *LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, uint LineNo, LLVMValueRef Ty, bool IsLocalToUnit,
    LLVMValueRef Val, LLVMValueRef Decl) {
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  auto T = unwrapMDAs<DIType>(Ty);
  auto C = dyn_cast<Constant>(unwrap(Val));
#if LLVM_VERSION_MINOR >= 7
  auto D = unwrapMDAs<MDNode>(Decl);
#else
  auto D = dyn_cast_or_null<MDNode>(unwrapMD(Decl));
#endif
  return wrap(unwrap(builder)->createGlobalVariable(
      S, StringRef(Name, NameLen), StringRef(LinkageName, LinkageNameLen),
      F, LineNo, T, IsLocalToUnit, C, D));
}

LLVMValueRef LLVMDIBuilderCreateFunction(
    LLVMDIBuilderRef builder, LLVMValueRef Scope, const char *Name,
    size_t NameLen, const char *LinkageName, size_t LinkageNameLen,
    LLVMValueRef File, unsigned LineNo, LLVMValueRef Ty, bool isLocalToUnit,
    bool isDefinition, unsigned ScopeLine, unsigned Flags, bool isOptimized,
    LLVMValueRef Fn, LLVMValueRef TParam, LLVMValueRef Decl) {
  StringRef N(Name, NameLen);
  StringRef LN(LinkageName, LinkageNameLen);
  auto B = unwrap(builder);
  auto S = unwrapMDAs<DIScope>(Scope);
  auto F = unwrapMDAs<DIFile>(File);
  auto T = unwrapMDAs<DISubroutineType>(Ty);
  auto FN = dyn_cast<Function>(unwrap(Fn));
#if LLVM_VERSION_MINOR >= 7
  auto TP = unwrapMDAs<MDNode>(TParam);
  auto D = unwrapMDAs<MDNode>(Decl);
#else
  auto TP = dyn_cast_or_null<MDNode>(unwrapMD(TParam));
  auto D = dyn_cast_or_null<MDNode>(unwrapMD(Decl));
#endif

  return wrap(B->createFunction(S, N, LN, F, LineNo, T, isLocalToUnit,
	 isDefinition, ScopeLine, Flags, isOptimized, FN, TP, D));
}

void LLVMDIBuilderStructSetBody(LLVMDIBuilderRef builder,
                                LLVMValueRef Struct,
                                LLVMValueRef *Elements,
                                size_t ElementsNum) {
  auto B = unwrap(builder);
  auto fwd = unwrapMDAs<DICompositeType>(Struct);

  SmallVector<Metadata *, 8> MDs;
  for (int i = 0; i < ElementsNum; i++) {
    auto *MD = unwrapMD(Elements[i]);
    // TODO Extract?
    MDs.push_back(MD);
  }

#if LLVM_VERSION_MINOR >= 7
  fwd->replaceElements(B->getOrCreateArray(MDs));
#else
  B->replaceArrays(fwd, B->getOrCreateArray(MDs));
#endif
}
