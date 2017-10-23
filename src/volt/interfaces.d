/*#D*/
// Copyright © 2012-2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.interfaces;

import core.exception;
import volt.token.location;
import ir = volt.ir.ir;


/*!
 * Each of these listed platforms corresponds
 * to a Version identifier.
 *
 * Posix and Windows are not listed here as they
 * they are available on multiple platforms.
 *
 * Posix on Linux and OSX.
 * Windows on MinGW and MSVC.
 */
enum CRuntime
{
	None,
	MinGW,
	Glibc,
	Darwin,
	Microsoft,
}

string cRuntimeToString(CRuntime cRuntime)
{
	final switch (cRuntime) with (CRuntime) {
	case None: return "none";
	case MinGW: return "mingw";
	case Glibc: return "glibc";
	case Darwin: return "darwin";
	case Microsoft:  return "microsoft";
	}
}

/*!
 * Each of these listed platforms corresponds
 * to a Version identifier.
 *
 * Posix and Windows are not listed here as they
 * they are available on multiple platforms.
 *
 * Posix on Linux and OSX.
 * Windows on MinGW and MSVC.
 */
enum Platform
{
	MinGW,
	MSVC,
	Linux,
	OSX,
	Metal,
}

string platformToString(Platform platform)
{
	final switch (platform) with (Platform) {
	case MinGW: return "mingw";
	case MSVC:  return "msvc";
	case Linux: return "linux";
	case OSX:   return "osx";
	case Metal: return "metal";
	}
}

/*!
 * Each of these listed architectures corresponds
 * to a Version identifier.
 */
enum Arch
{
	X86,
	X86_64,
}

string archToString(Arch arch)
{
	final switch (arch) with (Arch) {
	case X86: return "x86";
	case X86_64: return "x86_64";
	}
}

/*!
 * Holds information about the target that we are compiling to.
 */
class TargetInfo
{
	Arch arch;
	Platform platform;
	CRuntime cRuntime;

	size_t ptrSize;

	struct Alignments
	{
		size_t int1;      // bool
		size_t int8;      // byte, ubyte, char
		size_t int16;     // short, ushort, wchar
		size_t int32;     // int, uint, dchar
		size_t int64;     // long, ulong
		size_t float32;   // float
		size_t float64;   // double
		size_t ptr;       // pointer, class ref
		size_t aggregate; // struct, class, delegate
	}

	Alignments alignment;

	//! Are pointers 64bit for this target.
	bool isP64;
	//! Does this target have exception handling.
	bool haveEH;
}

/*!
 * A set of version/debug identifiers.
 */
final class VersionSet
{
public:
	bool debugEnabled;

	//! These are always set
	enum string[] defaultVersions = [
		"all",
		"Volt",
	];

	enum string[] reservedVersions = [
		// Generic
		"all",
		"none",
		"Volt",
		// Arch
		"X86",
		"X86_64",
		"LE32",
		// Platforms
		"Posix",
		"Windows",
		// Targets
		"OSX",
		"MSVC",
		"Linux",
		"MinGW",
		"Solaris",
		"FreeBSD",
		"Standalone",
		"Emscripten",
		// Misc
		"V_P32",
		"V_P64",
		// C runtime flags
		"CRuntime_All",
		"CRuntime_Any",
		"CRuntime_None",
		"CRuntime_Glibc",
		"CRuntime_Bionic",
		"CRuntime_Microsoft",
	];

private:
	//! If the ident exists and is true, it's set, if false it's reserved.
	bool[string] mVersionIdentifiers;
	//! If the ident exists, it's set.
	bool[string] mDebugIdentifiers;


public:
	this()
	{
		foreach (r; reservedVersions) {
			reserveVersionIdentifier(r);
		}

		foreach (d; defaultVersions) {
			overwriteVersionIdentifier(d);
		}
	}

	//! Throws: Exception if ident is reserved.
	final void setVersionIdentifier(string ident)
	{
		if (auto p = ident in mVersionIdentifiers) {
			if (!(*p)) {
				throw new Exception("cannot set reserved identifier.");
			}
		}
		mVersionIdentifiers[ident] = true;
	}

	//! Doesn't throw on ident reserve.
	final void overwriteVersionIdentifier(string ident)
	{
		mVersionIdentifiers[ident] = true;
	}

	//! Doesn't throw, debug identifiers can't be reserved.
	final void setDebugIdentifier(string ident)
	{
		mDebugIdentifiers[ident] = true;
	}

	/*!
	 * Check if a given version identifier is set.
	 * Params:
	 *   ident = the identifier to check.
	 * Returns: true if set, false otherwise.
	 */
	final bool isVersionSet(string ident)
	{
		if (auto p = ident in mVersionIdentifiers) {
			return *p;
		} else {
			return false;
		}
	}

	/*!
	 * Check if a given debug identifier is set.
	 * Params:
	 *   ident = the identifier to check.
	 * Returns: true if set, false otherwise.
	 */
	final bool isDebugSet(string ident)
	{
		return (ident in mDebugIdentifiers) !is null;
	}

	/*!
	 * Quick helpers to get version flags.
	 * @{
	 */
	@property bool isP64() { return isVersionSet("V_P64"); }
	/*!
	 * @}
	 */

private:
	//! Marks an identifier as unable to be set. Doesn't set the identifier.
	final void reserveVersionIdentifier(string ident)
	{
		mVersionIdentifiers[ident] = false;
	}
}

/*!
 * Home to logic for tying Frontend, Pass and Backend together and
 * abstracts away several IO related functions. Such as looking up
 * module files and printing error messages.
 */
abstract class Driver
{
public:
	string execDir;
	string identStr;
	bool internalDebug;


public:
	//! Free resources.
	abstract void close();

	//! Load a module source from file system.
	abstract ir.Module loadModule(ir.QualifiedName name);

	//! Load a filename from the string import paths.
	abstract string stringImport(ref in Location loc, string filename);

	//! Get the modules given on the command line.
	abstract ir.Module[] getCommandLineModules();

	/*!
	 * Returns a delegate that runs the given function from
	 * the given module.
	 *
	 * May be called multiple times with the same arguments,
	 * or the same Module but with a different function from
	 * the given Module.
	 *
	 * The driver should do caching of the module and function.
	 * Once a module has been given to it or any children of it
	 * may not be changed, doing so will cause undefined behaviour.
	 */
	abstract BackendHostResult hostCompile(ir.Module);
}

/*!
 * @defgroup parsing Parsing
 * @brief Code that turns text into ir nodes.
 *
 * The beginning of the compilation pipeline, this lexes the source code,
 * parses the resulting tokens and does some very lightweight transformation
 * of the internal AST into Volt IR.
 */

/*!
 * The part of the compiler that takes user supplied code and turns it into IR.
 *
 * @ingroup parsing
 */
interface Frontend
{
	//! Free resources.
	void close();

	/*!
	 * Parse a module and all its children from the given source.
	 * Filename is the file from which file the source was loaded from.
	 *
	 * @param[in] source The complete source of the module to be parsed.
	 * @param[in] filename The path to the module, ir nodes locations gets
	 *                     gets tagged with this filename.
	 * @return The parsed module.
	 */
	ir.Module parseNewFile(string source, string filename);

	/*!
	 * Parse a zero or more statements from a string, does not
	 * need to start with '{' or end with a '}'.
	 *
	 * Used for string mixins in functions.
	 *
	 * @param[in] source The source of the statements to be parsed.
	 * @param[in] loc The location of the mixin that this originated from.
	 * @return The parsed statements.
	 */
	ir.Node[] parseStatements(string source, Location loc);

}

/*!
 * @defgroup semantic Volt Semantics
 * @brief The code that implements the semantic rules of Volt.
 */

/*!
 * @defgroup passes Passes
 * @brief Volt transforms code by running multiple 'passes' that mutate the code.
 */

/*!
 * Interface implemented by transformation, debug and/or validation passes.
 *
 * Transformation passes often lowers high level Volt IR into something
 * that is easier for backends to handle.
 *
 * Validation passes validates the Volt IR, and reports errors, often halting
 * compilation by throwing CompilerError.
 *
 * @ingroup passes
 */
interface Pass
{
	//! Free resources.
	void close();

	//! Run the pass on the given module.
	void transform(ir.Module m);
}

/*!
 * @defgroup passLang Language Passes
 * @brief Language Passes verify and mutate parsed modules.
 *
 * The language passes are divided into three phases:
 * 1. Post Parse
 * 2. Expression Type Verification
 * 3. Miscellaneous
 *
 * @link passPost Phase 1, PostParse @endlink, works like this:
 * 1. All of the version statements are resolved for the entire module.
 * 2. Then, for each Module, Class, Struct, and Enum's TopLevelBlock:
 *   1. Apply all attributes in the current block or its direct children.
 *   2. Add symbols to scope in the current block or its direct children.
 *   3. Then do those steps for for each child TopLevelBlock that
 *      brings in a new scope (Classes, Enums, Structs).
 * 3. Resolve the imports.
 * 4. Go from top to bottom resolving static ifs (applying step 2
 *    to the selected TopLevelBlock).
 *
 * @link passSem Phase 2, Semantic @endlink, is a complex step that resolves and typechecks
 * any expressions. This pass is only run for modules that are passed
 * directly to the LanguagePass.transform function, or functions that
 * are invoked by static ifs.
 *
 * @link passLower Phase 3, Lowering @endlink, are various lowering and transformation passes, some can
 * invoke Phase 1 and 2 on newly generated code.
 *
 * @ingroup passes
 */

/*!
 * @defgroup passPost Post Parsing Passes
 * @brief Passes that are run after parsing.
 *
 * These are the passes that the LanguagePass runs after parsing is done.
 *
 * @sa The input for post parse is often generated by @ref parsing.
 * @sa After post parse @ref passSem are run.
 * @ingroup passLang
 */

/*!
 * @defgroup passSem Semantic Passes
 * @brief Semantic passes check for errors and resolves implicit types.
 *
 * Semantic passes transform the code and checks for errors.
 *
 * @sa Semantic passes handle ir after @ref passPost.
 * @sa IR transformed by semantic passes are often lowered by @ref passLower.
 * @ingroup semantic passLang
 */

/*!
 * @defgroup passLower Lowering Passes
 * @brief Lowers ir before being passed off to the backend.
 *
 * Lowers complicated constructs into multiple simple constructs.
 * foreach becomes a for loop, assert becomes an if and a throw, etc.
 *
 * @sa Modules given must be checkd by @ref passSem.
 * @sa The @ref backend is often the consumer of the transformed IR.
 * @ingroup passLang
 */

/*!
 * Centre point for all language passes.
 * @ingroup sementic passes passLang
 */
abstract class LanguagePass
{
public:
	//! The driver that created this LanguagePass.
	Driver driver;

	//! Holds the current version symbols for this comile.
	VersionSet ver;

	//! For which target are we compiling against.
	TargetInfo target;

	//! Parsing front to be used when parsing new code.
	Frontend frontend;

	//! Should the code emit warnings.
	bool warningsEnabled;

	/*!
	 * Cached lookup items.
	 * @{
	 */
	// core.object
	ir.Class objObject;

	// core.varargs
	ir.Function vaStartFunc;
	ir.Function vaEndFunc;

	// core.typeinfo
	ir.Class tiTypeInfo;
	ir.Class tiClassInfo;
	ir.Class tiInterfaceInfo;

	// core.exception
	ir.Class exceptThrowable;

	// core.rt.gc
	ir.Variable gcAllocDgVariable;

	// core.rt.aa
	ir.Function aaNew;               // vrt_aa_new
	ir.Function aaDup;               // vrt_aa_dup
	ir.Function aaRehash;            // vrt_aa_rehash
	ir.Function aaGetKeys;           // vrt_aa_get_keys
	ir.Function aaGetValues;         // vrt_aa_get_values
	ir.Function aaGetLength;         // vrt_aa_get_length
	ir.Function aaInsertPrimitive;   // vrt_aa_insert_primitive
	ir.Function aaInsertArray;       // vrt_aa_insert_array
	ir.Function aaInsertPtr;         // vrt_aa_insert_ptr
	ir.Function aaDeletePrimitive;   // vrt_aa_delete_primitive
	ir.Function aaDeleteArray;       // vrt_aa_delete_array
	ir.Function aaDeletePtr;         // vrt_aa_delete_ptr
	ir.Function aaInPrimitive;       // vrt_aa_in_primitive
	ir.Function aaInArray;           // vrt_aa_in_array
	ir.Function aaInPtr;             // vrt_aa_in_ptr
	ir.Function aaInBinopPrimitive;  // vrt_aa_in_binop_primitive
	ir.Function aaInBinopArray;      // vrt_aa_in_binop_array
	ir.Function aaInBinopPtr;        // vrt_aa_in_binop_ptr

	// core.rt.misc
	ir.Function hashFunc;
	ir.Function castFunc;
	ir.Function memcmpFunc;
	ir.Function utfDecode_u8_d;
	ir.Function utfReverseDecode_u8_d;
	ir.Function ehThrowFunc;
	ir.Function ehThrowSliceErrorFunc;
	ir.Function ehPersonalityFunc;
	ir.Function ehThrowAssertErrorFunc;
	ir.Function ehThrowKeyNotFoundErrorFunc;
	ir.Function runMainFunc;

	// core.compiler.llvm
	ir.Function llvmTypeidFor;
	ir.Function llvmMemmove32;
	ir.Function llvmMemmove64;
	ir.Function llvmMemcpy32;
	ir.Function llvmMemcpy64;
	ir.Function llvmMemset32;
	ir.Function llvmMemset64;

	// core.rt.format;
	ir.Type sinkType;
	ir.Type sinkStore;
	ir.Function sinkInit;
	ir.Function sinkGetStr;
	ir.Function formatHex;
	ir.Function formatI64;
	ir.Function formatU64;
	ir.Function formatF32;
	ir.Function formatF64;
	ir.Function formatDchar;
	//! @}

	/*!
	 * Type id constants for TypeInfo.
	 * @{
	 */
	int TYPE_STRUCT;
	int TYPE_CLASS;
	int TYPE_INTERFACE;
	int TYPE_UNION;
	int TYPE_ENUM;
	int TYPE_ATTRIBUTE;
	int TYPE_ANNOTATION;

	int TYPE_VOID;
	int TYPE_UBYTE;
	int TYPE_BYTE;
	int TYPE_CHAR;
	int TYPE_BOOL;
	int TYPE_USHORT;
	int TYPE_SHORT;
	int TYPE_WCHAR;
	int TYPE_UINT;
	int TYPE_INT;
	int TYPE_DCHAR;
	int TYPE_FLOAT;
	int TYPE_ULONG;
	int TYPE_LONG;
	int TYPE_DOUBLE;
	int TYPE_REAL;

	int TYPE_POINTER;
	int TYPE_ARRAY;
	int TYPE_STATIC_ARRAY;
	int TYPE_AA;
	int TYPE_FUNCTION;
	int TYPE_DELEGATE;
	//! @}


public:
	this(Driver drv, VersionSet ver, TargetInfo target, Frontend frontend)
	out {
		assert(this.ver !is null);
		assert(this.target !is null);
		assert(this.driver !is null);
		assert(this.frontend !is null);
	}
	body {
		this.ver = ver;
		this.target = target;
		this.driver = drv;
		this.frontend = frontend;
	}

	//! Free resources.
	abstract void close();

	/*!
	 * Used by the Driver to store classes it loads from arguments.
	 *
	 * The controller does not need to call addModule when it has loaded a
	 * module via its loadModule function.
	 */
	abstract void addModule(ir.Module mod);

	/*!
	 * Returns a already loaded module or loads it from file.
	 *
	 * The expected behavior of the langauge pass is to call the Driver
	 * to load the module.
	 */
	abstract ir.Module getModule(ir.QualifiedName name);

	/*!
	 * Retuns all currently loaded modules.
	 */
	abstract ir.Module[] getModules();


	/*
	 *
	 * Circular dependancy checker.
	 *
	 */

	alias DoneDg = void delegate();

	/*!
	 * These functions are used to assure that no circular dependancies
	 * happens when resolving nodes like: Class, Function, Variables, etc.
	 * @{
	 */
	abstract DoneDg startResolving(ir.Node n);
	abstract DoneDg startActualizing(ir.Node n);
	/*!
	 * @}
	 */


	/*
	 *
	 * Resolve functions.
	 *
	 */

	/*!
	 * Gathers all the symbols and adds scopes where needed from
	 * the given block statement.
	 *
	 * This function is intended to be used for inserting new
	 * block statements into already gathered functions, for
	 * instance when processing mixin statemetns.
	 */
	abstract void gather(ir.Scope current, ir.BlockStatement bs);

	/*!
	 * Resolves an Attribute, for UserAttribute usages.
	 */
	abstract void resolve(ir.Scope current, ir.Attribute a);

	/*!
	 * Resolve a set of user attributes.
	 */
	abstract void resolve(ir.Scope current, ir.Attribute[] userAttrs);

	/*!
	 * Resolves an ExpReference, forwarding the decl appropriately.
	 */
	abstract void resolve(ir.Scope current, ir.ExpReference eref);

	/*!
	 * Resolves an EnumDeclaration setting its value.
	 *
	 * @throws CompilerError on failure to resolve the enum value.
	 */
	abstract void resolve(ir.Scope current, ir.EnumDeclaration ed);

	/*!
	 * Resolves an ir.Store that is of kind Merge. Afterwards the kind
	 * is changed to kind Function, since only functions can be merged.
	 */
	abstract void resolve(ir.Store);

	/*!
	 * Resolves a Function making it usable externaly,
	 *
	 * @throws CompilerError on failure to resolve function.
	 */
	final void resolve(ir.Scope current, ir.Function func)
	{ if (!func.isResolved) doResolve(current, func); }

	/*!
	 * Resolves a Variable making it usable externaly.
	 *
	 * @throws CompilerError on failure to resolve variable.
	 */
	final void resolve(ir.Scope current, ir.Variable v)
	{ if (!v.isResolved) doResolve(current, v); }

	/*!
	 * Resolves a unresolved alias store, the store can
	 * change type to Type, either the field myAlias or
	 * type is set.
	 *
	 * @throws CompilerError on failure to resolve alias.
	 */
	final void resolve(ir.Alias a)
	{ if (!a.isResolved) doResolve(a); }

	/*!
	 * Resolves an Enum making it usable externaly, done on lookup of it.
	 *
	 * @throws CompilerError on failure to resolve the enum.
	 */
	final void resolveNamed(ir.Enum e)
	{ if (!e.isResolved) doResolve(e); }

	/*!
	 * Resolves a Struct, done on lookup of it.
	 */
	final void resolveNamed(ir.Struct s)
	{ if (!s.isResolved) doResolve(s); }

	/*!
	 * Resolves a Union, done on lookup of it.
	 */
	final void resolveNamed(ir.Union u)
	{ if (!u.isResolved) doResolve(u); }

	/*!
	 * Resolves a Class, making sure the parent class is populated.
	 */
	final void resolveNamed(ir.Class c)
	{ if (!c.isResolved) doResolve(c); }

	/*!
	 * Resolves an Interface.
	 */
	final void resolveNamed(ir._Interface i)
	{ if (!i.isResolved) doResolve(i); }

	/*!
	 * Actualize a Struct, making sure all its fields and methods
	 * are populated, and any embedded structs (not referenced
	 * via pointers) are actualized as well. In short makes sure
	 * that the struct size is fully known.
	 */
	final void actualize(ir.Struct s)
	{ if (!s.isActualized) doActualize(s); }

	/*!
	 * Actualize a Union, making sure all its fields and methods
	 * are populated, and any embedded structs (not referenced
	 * via pointers) are resolved as well.
	 */
	final void actualize(ir.Union u)
	{ if (!u.isActualized) doActualize(u); }

	/*!
	 * Actualize an Interface.
	 */
	final void actualize(ir._Interface i)
	{ if (!i.isActualized) doActualize(i); }

	/*!
	 * Actualize a Class, making sure all its fields and methods
	 * are populated, Any embedded structs (not referenced via
	 * pointers) are resolved as well. Parent classes are
	 * resolved to.
	 *
	 * Any lowering structs and internal variables are also
	 * generated by this function.
	 */
	final void actualize(ir.Class c)
	{ if (!c.isActualized) doActualize(c); }


	/*
	 *
	 * General phases functions.
	 *
	 */

	/*!
	 * Run all post parse passes on the given modules.
	 *
	 * @param[in] m The modules.
	 * @ingroup passPost
	 */
	abstract void phase1(ir.Module[] m);

	/*!
	 * Run all semantic passes on the given modules.
	 *
	 * @param[in] m The modules.
	 * @ingroup passSem
	 */
	abstract void phase2(ir.Module[] m);

	/*!
	 * Run all lowering passes on the given modules.
	 *
	 * @param[in] m The modules.
	 * @ingroup passLower
	 */
	abstract void phase3(ir.Module[] m);


	/*
	 *
	 * Protected action functions.
	 *
	 */

protected:
	abstract void doResolve(ir.Scope current, ir.Variable v);
	abstract void doResolve(ir.Scope current, ir.Function func);
	abstract void doResolve(ir.Alias a);
	abstract void doResolve(ir.Enum e);
	abstract void doResolve(ir._Interface i);
	abstract void doResolve(ir.Class c);
	abstract void doResolve(ir.Union u);
	abstract void doResolve(ir.Struct c);

	abstract void doActualize(ir._Interface i);
	abstract void doActualize(ir.Struct s);
	abstract void doActualize(ir.Union u);
	abstract void doActualize(ir.Class c);
}

/*!
 * @defgroup backend Backend
 * @brief Code and classes that turn modules into machine code.
 */

/*!
 * Used to determine the output of the backend.
 *
 * @ingroup backend
 */
enum TargetType
{
	DebugPrinting,
	LlvmBitcode,
	VoltCode,
	Object,
	CCode,
	Host,
}

/*!
 * Interface implemented by backends. Often the last stage of the compile
 * pipe that is implemented in this compiler, optimization and linking
 * are often done outside of the compiler, either invoked directly by us
 * or a build system.
 *
 * ## See also
 *   - @ref passLower makes modules suitable for the backend.
 *
 * @ingroup backend
 */
interface Backend
{
public:
	//! Free resources.
	void close();

	//! Return the supported target types.
	TargetType[] supported();

	/*!
	 * Compile the given module to either a file or host result.
	 *
	 * See the corresponding fields on LanguagePass and Driver for what
	 * the non-Module arguments mean.
	 * @{
	 */
	BackendFileResult compileFile(ir.Module m, TargetType type,
		ir.Function ehPersonality, ir.Function llvmTypeidFor,
		string execDir, string identStr);

	BackendHostResult compileHost(ir.Module m,
		ir.Function ehPersonality, ir.Function llvmTypeidFor,
		string execDir, string identStr);
	//! @}
}

/*!
 * A result from a backend compilation that can be saved onto disk.
 *
 * @ingroup backend
 */
interface BackendFileResult
{
public:
	//! Free resources.
	void close();

	//! Save the result to disk.
	void saveToFile(string filename);
}

/*!
 * A JIT compiled a module that you can fetch functions from.
 *
 * @ingroup backend
 */
interface BackendHostResult
{
public:
	//! Free resources.
	void close();

	//! Return from getFunction method.
	alias CompiledDg = ir.Constant delegate(ir.Constant[]);

	/*!
	 * Returns a delegate that runs the given function from
	 * the module that this object was compiled from.
	 *
	 * The function must have been inside of the module. May be called
	 * multiple times with the same function, or different function.
	 *
	 * This object should do caching of the function. Once a module has
	 * been given to the driver any children of it may not be changed,
	 * doing so will cause undefined behaviour.
	 */
	CompiledDg getFunction(ir.Function);
}
