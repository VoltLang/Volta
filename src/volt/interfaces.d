// Copyright © 2012-2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.interfaces;

import core.exception;
import volt.token.location;
import ir = volt.ir.ir;


/**
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
	EMSCRIPTEN,
	Metal,
}

/**
 * Each of these listed architectures corresponds
 * to a Version identifier.
 */
enum Arch
{
	X86,
	X86_64,
	LE32, // Generic little endian
}

/**
 * Holds information about the target that we are compiling to.
 */
class TargetInfo
{
	Arch arch;
	Platform platform;

	bool isP64;
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
}

/**
 * A set of version/debug identifiers.
 */
final class VersionSet
{
public:
	bool debugEnabled;

	/// These are always set
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
		"Emscripten",
		// Misc
		"V_P32",
		"V_P64",
	];

private:
	/// If the ident exists and is true, it's set, if false it's reserved.
	bool[string] mVersionIdentifiers;
	/// If the ident exists, it's set.
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

	/// Throws: Exception if ident is reserved.
	final void setVersionIdentifier(string ident)
	{
		if (auto p = ident in mVersionIdentifiers) {
			if (!(*p)) {
				throw new Exception("cannot set reserved identifier.");
			}
		}
		mVersionIdentifiers[ident] = true;
	}

	/// Doesn't throw on ident reserve.
	final void overwriteVersionIdentifier(string ident)
	{
		mVersionIdentifiers[ident] = true;
	}

	/// Doesn't throw, debug identifiers can't be reserved.
	final void setDebugIdentifier(string ident)
	{
		mDebugIdentifiers[ident] = true;
	}

	/**
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

	/**
	 * Check if a given debug identifier is set.
	 * Params:
	 *   ident = the identifier to check.
	 * Returns: true if set, false otherwise.
	 */
	final bool isDebugSet(string ident)
	{
		return (ident in mDebugIdentifiers) !is null;
	}

	/**
	 * Quick helpers to get version flags.
	 * @{
	 */
	@property bool isP64() { return isVersionSet("V_P64"); }
	/**
	 * @}
	 */

private:
	/// Marks an identifier as unable to be set. Doesn't set the identifier.
	final void reserveVersionIdentifier(string ident)
	{
		mVersionIdentifiers[ident] = false;
	}
}

/**
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
	/// Load a module source from file system.
	abstract ir.Module loadModule(ir.QualifiedName name);

	/// Load a filename from the string import paths.
	abstract string stringImport(Location loc, string filename);

	/// Get the modules given on the command line.
	abstract ir.Module[] getCommandLineModules();

	/**
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
	abstract BackendResult hostCompile(ir.Module);

	abstract void close();
}

/**
 * Start of the compile pipeline, it lexes source, parses tokens and do
 * some very lightweight transformation of internal AST into Volt IR.
 */
interface Frontend
{
	/**
	 * Parse a module and all its children from the given source.
	 * Filename is the file from which file the source was loaded from.
	 *
	 * Returns:
	 *   The parsed module.
	 */
	ir.Module parseNewFile(string source, string filename);

	/**
	 * Parse a zero or more statements from a string, does not
	 * need to start with '{' or end with a '}'.
	 *
	 * Used for string mixins in functions.
	 *
	 * Returns:
	 *   Returns the parsed statements.
	 */
	ir.Node[] parseStatements(string source, Location loc);

	void close();
}

/**
 * @defgroup passes Passes
 * @brief Volt is a passes based compiler.
 */

/**
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
	void transform(ir.Module m);

	void close();
}

/**
 * @defgroup passLang Language Passes
 * @ingroup passes
 * @brief Language Passes verify and slightly transforms parsed modules.
 *
 * The language passes are devided into 3 main phases:
 * 1. PostParse
 * 2. Exp Type Verification
 * 3. Misc
 *
 * Phase 1, PostParse, works like this:
 * 1. All of the version statements are resolved for the entire module.
 * 2. Then for each Module, Class, Struct, Enum's TopLevelBlock.
 *   1. Apply all attributes in the current block or direct children.
 *   2. Add symbols to scope in the current block or direct children.
 *   3. Then do step a-c for for each child TopLevelBlock that
 *      brings in a new scope (Classes, Enums, Structs).
 * 3. Resolve the imports.
 * 4. Going from top to bottom resolving static if (applying step 2
 *    to the selected TopLevelBlock).
 *
 * Phase 2, ExpTyper, is just a single complex step that resolves and typechecks
 * any expressions, this pass is only run for modules that are called
 * directly by the LanguagePass.transform function, or functions that
 * are invoked by static ifs.
 *
 * Phase 3, Misc, are various lowering and transformation passes, some can
 * inoke Phase 1 and 2 on newly generated code.
 */

/**
 * Center point for all language passes.
 * @ingroup passes passLang
 */
abstract class LanguagePass
{
public:
	Driver driver;
	VersionSet ver;
	TargetInfo target;
	Frontend frontend;

	/**
	 * For controlling if we should accept some D constructs.
	 */
	bool beMoreLikeD;

	bool warningsEnabled;

	/**
	 * Cached lookup items.
	 * @{
	 */
	// core.object
	ir.Class objObject;
	ir.Class objAttribute;

	// core.varargs
	ir.Function vaStartFunc;
	ir.Function vaEndFunc;

	// core.typeinfo
	ir.Class tiTypeInfo;
	ir.Class tiClassInfo;
	ir.Class tiInterfaceInfo;

	// core.exception
	ir.Class exceptThrowable;
	ir.Class exceptAssertError;
	ir.Class exceptKeyNotFoundException;

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
	ir.Function aaDeletePrimitive;   // vrt_aa_delete_primitive
	ir.Function aaDeleteArray;       // vrt_aa_delete_array
	ir.Function aaInPrimitive;       // vrt_aa_in_primitive
	ir.Function aaInArray;           // vrt_aa_in_array
	ir.Function aaInBinopPrimitive;  // vrt_aa_in_binop_primitive
	ir.Function aaInBinopArray;      // vrt_aa_in_binop_array
	ir.Function aaGetPP;             // vrt_aa_get_pp
	ir.Function aaGetAA;             // vrt_aa_get_aa
	ir.Function aaGetPA;             // vrt_aa_get_pa
	ir.Function aaGetAP;             // vrt_aa_get_ap

	// core.rt.misc
	ir.Struct moduleInfo;
	ir.Variable moduleInfoRoot;
	ir.Function hashFunc;
	ir.Function castFunc;
	ir.Function memcmpFunc;
	ir.Function utfDecode_u8_d;
	ir.Function utfReverseDecode_u8_d;
	ir.Function ehThrowFunc;
	ir.Function ehThrowSliceErrorFunc;
	ir.Function ehPersonalityFunc;

	// core.compiler.llvm
	ir.Function llvmTypeidFor;
	ir.Function llvmMemmove32;
	ir.Function llvmMemmove64;
	ir.Function llvmMemcpy32;
	ir.Function llvmMemcpy64;
	ir.Function llvmMemset32;
	ir.Function llvmMemset64;

	/* @} */

	/**
	 * Type id constants for TypeInfo.
	 * @{
	 */
	int TYPE_STRUCT;
	int TYPE_CLASS;
	int TYPE_INTERFACE;
	int TYPE_UNION;
	int TYPE_ENUM;
	int TYPE_ATTRIBUTE;
	int TYPE_USER_ATTRIBUTE;

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
	/* @} */

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

	abstract void close();

	/**
	 * Used by the Driver to store classes it loads from arguments.
	 *
	 * The controller does not need to call addModule when it has loaded a
	 * module via its loadModule function.
	 */
	abstract void addModule(ir.Module mod);

	/**
	 * Returns a already loaded module or loads it from file.
	 *
	 * The expected behavior of the langauge pass is to call the Driver
	 * to load the module.
	 */
	abstract ir.Module getModule(ir.QualifiedName name);

	/**
	 * Retuns all currently loaded modules.
	 */
	abstract ir.Module[] getModules();


	/*
	 *
	 * Circular dependancy checker.
	 *
	 */

	alias DoneDg = void delegate();

	/**
	 * These functions are used to assure that no circular dependancies
	 * happens when resolving nodes like: Class, Function, Variables, etc.
	 * @{
	 */
	abstract DoneDg startResolving(ir.Node n);
	abstract DoneDg startActualizing(ir.Node n);
	/**
	 * @}
	 */


	/*
	 *
	 * Resolve functions.
	 *
	 */

	/**
	 * Gathers all the symbols and adds scopes where needed from
	 * the given block statement.
	 *
	 * This function is intended to be used for inserting new
	 * block statements into already gathered functions, for
	 * instance when processing mixin statemetns.
	 */
	abstract void gather(ir.Scope current, ir.BlockStatement bs);

	/**
	 * Resolves an Attribute, for UserAttribute usages.
	 */
	abstract void resolve(ir.Scope current, ir.Attribute a);

	/**
	 * Resolve a set of user attributes.
	 */
	abstract void resolve(ir.Scope current, ir.Attribute[] userAttrs);

	/**
	 * Resolves an ExpReference, forwarding the decl appropriately.
	 */
	abstract void resolve(ir.Scope current, ir.ExpReference eref);

	/**
	 * Resolves an EnumDeclaration setting its value.
	 *
	 * @throws CompilerError on failure to resolve the enum value.
	 */
	abstract void resolve(ir.Scope current, ir.EnumDeclaration ed);

	/**
	 * Resolves an ir.Store that is of kind Merge. Afterwards the kind
	 * is changed to kind Function, since only functions can be merged.
	 */
	abstract void resolve(ir.Store);

	/**
	 * Resolves a Function making it usable externaly,
	 *
	 * @throws CompilerError on failure to resolve function.
	 */
	final void resolve(ir.Scope current, ir.Function func)
	{ if (!func.isResolved) doResolve(current, func); }

	/**
	 * Resolves a Variable making it usable externaly.
	 *
	 * @throws CompilerError on failure to resolve variable.
	 */
	final void resolve(ir.Scope current, ir.Variable v)
	{ if (!v.isResolved) doResolve(current, v); }

	/**
	 * Resolves a unresolved alias store, the store can
	 * change type to Type, either the field myAlias or
	 * type is set.
	 *
	 * @throws CompilerError on failure to resolve alias.
	 */
	final void resolve(ir.Alias a)
	{ if (!a.isResolved) doResolve(a); }

	/**
	 * Resolves an Enum making it usable externaly, done on lookup of it.
	 *
	 * @throws CompilerError on failure to resolve the enum.
	 */
	final void resolveNamed(ir.Enum e)
	{ if (!e.isResolved) doResolve(e); }

	/**
	 * Resolves a Struct, done on lookup of it.
	 */
	final void resolveNamed(ir.Struct s)
	{ if (!s.isResolved) doResolve(s); }

	/**
	 * Resolves a Union, done on lookup of it.
	 */
	final void resolveNamed(ir.Union u)
	{ if (!u.isResolved) doResolve(u); }

	/**
	 * Resolves a Class, making sure the parent class is populated.
	 */
	final void resolveNamed(ir.Class c)
	{ if (!c.isResolved) doResolve(c); }

	/**
	 * Resolves an Interface.
	 */
	final void resolveNamed(ir._Interface i)
	{ if (!i.isResolved) doResolve(i); }

	/**
	 * Resolves a UserAttribute, done on lookup of it.
	 */
	final void resolveNamed(ir.UserAttribute au)
	{ if (!au.isResolved) doResolve(au); }

	/**
	 * Actualize a Struct, making sure all its fields and methods
	 * are populated, and any embedded structs (not referenced
	 * via pointers) are actualized as well. In short makes sure
	 * that the struct size is fully known.
	 */
	final void actualize(ir.Struct s)
	{ if (!s.isActualized) doActualize(s); }

	/**
	 * Actualize a Union, making sure all its fields and methods
	 * are populated, and any embedded structs (not referenced
	 * via pointers) are resolved as well.
	 */
	final void actualize(ir.Union u)
	{ if (!u.isActualized) doActualize(u); }

	/**
	 * Actualize an Interface.
	 */
	final void actualize(ir._Interface i)
	{ if (!i.isActualized) doActualize(i); }

	/**
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

	/**
	 * Actualize a Class, making sure all its fields are
	 * populated, thus making sure it can be used for
	 * validation of annotations.
	 *
	 * Any lowering classes/structs and internal variables
	 * are also generated by this function.
	 */
	final void actualize(ir.UserAttribute ua)
	{ if (!ua.isActualized) doActualize(ua); }


	/*
	 *
	 * General phases functions.
	 *
	 */

	abstract void phase1(ir.Module[] m);

	abstract void phase2(ir.Module[] m);

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
	abstract void doResolve(ir.UserAttribute ua);

	abstract void doActualize(ir._Interface i);
	abstract void doActualize(ir.Struct s);
	abstract void doActualize(ir.Union u);
	abstract void doActualize(ir.Class c);
	abstract void doActualize(ir.UserAttribute ua);
}

/**
 * @defgroup passLower Lowering Passes
 * @ingroup passes
 * @brief Lowers ir before being passed of to backends.
 */

/**
 * Used to determin the output of the backend.
 */
enum TargetType
{
	DebugPrinting,
	LlvmBitcode,
	ElfObject,
	VoltCode,
	CCode,
	Host,
}

/**
 * Interface implemented by backends. Often the last stage of the compile
 * pipe that is implemented in this compiler, optimization and linking
 * are often done outside of the compiler, either invoked directly by us
 * or a build system.
 */
interface Backend
{
	/**
	 * Return the supported target types.
	 */
	TargetType[] supported();

	/**
	 * Set the target output type. Backends usually only
	 * suppports one or two output types @see supported.
	 */
	void setTarget(TargetType type);

	/**
	 * Compile the given module. You need to have called setTarget before
	 * calling this function.
	 */
	BackendResult compile(ir.Module m);

	/**
	 * Free any resources that the backend has.
	 */
	void close();
}

/**
 * A result from a backend compilation.
 *
 * It can be a file that you can save onto disk.
 *
 * Or a JIT compiled a module that you can fetch functions from.
 */
interface BackendResult
{
	/**
	 * Save the result to disk.
	 */
	void saveToFile(string filename);

	alias CompiledDg = ir.Constant delegate(ir.Constant[]);

	/**
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

	/**
	 * Free any resources that this result has.
	 */
	void close();
}
