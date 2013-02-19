// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.interfaces;

import volt.token.location;
import ir = volt.ir.ir;


/**
 * Home to logic for tying Frontend, Pass and Backend together and
 * abstracts away several IO related functions. Such as looking up
 * module files and printing error messages.
 */
interface Controller
{
	ir.Module getModule(ir.QualifiedName name);

	void close();
}

/**
 * Start of the compile pipeline, it lexes source, parses tokens and do
 * some very lightweight transformation of internal AST into Volt IR.
 */
interface Frontend
{
	ir.Module parseNewFile(string source, Location loc);

	/**
	 * Parse a zero or more statements from a string, does not
	 * need to start with '{' or end with a '}'.
	 *
	 * Used for string mixins in functions.
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
class LanguagePass
{
public:
	Settings settings;
	Frontend frontend;
	Controller controller;

public:
	this(Settings settings, Frontend frontend, Controller controller)
	out {
		assert(this.settings !is null);
		assert(this.frontend !is null);
		assert(this.controller !is null);
	}
	body {
		this.settings = settings;
		this.frontend = frontend;
		this.controller = controller;
	}

	abstract void close();

	/**
	 * Helper function, often just routed to the Controller.
	 */
	abstract ir.Module getModule(ir.QualifiedName name);

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
	 * Resolves a Variable making it usable externaly,
	 *
	 * @throws CompilerError on failure to resolve variable.
	 */
	abstract void resolve(ir.Scope current, ir.Variable v);

	/**
	 * Resolves a Function making it usable externaly,
	 *
	 * @throws CompilerError on failure to resolve function.
	 */
	abstract void resolve(ir.Function fn);

	/**
	 * Resolves a unresolved TypeReference in the given scope.
	 * The TypeReference's type is set to the looked up type,
	 * should type be not null nothing is done.
	 */
	abstract void resolve(ir.Scope s, ir.TypeReference tr);

	/**
	 * Resolves a unresolved alias store, the store can
	 * change type to Type, either the field myAlias or
	 * type is set.
	 *
	 * @throws CompilerError on failure to resolve alias.
	 */
	abstract void resolve(ir.Store s);

	/**
	 * Resovles a Struct, does some things.
	 */
	abstract void resolve(ir.Struct c);

	/**
	 * Resovles a Class, making sure the parent is populated.
	 */
	abstract void resolve(ir.Class c);

	/**
	 * Actualize a Struct, making sure all its fields and methods
	 * are populated, and any embedded structs (not referenced
	 * via pointers) are resolved as well.
	 */
	abstract void actualize(ir.Struct c);

	/**
	 * Actualize a Class, making sure all its fields and methods
	 * are populated, Any embedded structs (not referenced via
	 * pointers) are resolved as well. Parent classes are
	 * resolved to.
	 *
	 * Any lowering structs and internal variables are also
	 * generated by this function.
	 */
	abstract void actualize(ir.Class c);

	/*
	 *
	 * General phases functions.
	 *
	 */

	abstract void phase1(ir.Module m);

	abstract void phase2(ir.Module[] m);

	abstract void phase3(ir.Module[] m);
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
	 * Set the target file and output type. Backends usually only
	 * suppports one or two output types @see supported.
	 */
	void setTarget(string filename, TargetType type);

	/**
	 * Compile the given module. You need to have called setTarget before
	 * calling this function. setTarget needs to be called for each
	 * invocation of this function.
	 */
	void compile(ir.Module m);

	void close();
}

/**
 * Each of these listed platforms corresponds
 * to a Version identifier.
 *
 * Posix and Windows are not listed here as they
 * they are available on multiple platforms.
 *
 * Posix on Linux and OSX.
 * Windows on MinGW.
 */
enum Platform
{
	MinGW,
	Linux,
	OSX,
}

/**
 * Each of these listed architectures corresponds
 * to a Version identifier.
 */
enum Arch
{
	X86,
	X86_64,
}

/**
 * Holds a set of compiler settings.
 *
 * Things like version/debug identifiers, warning mode,
 * debug/release, import paths, and so on.
 */
final class Settings
{
public:
	bool warningsEnabled; ///< The -w argument.
	bool debugEnabled; ///< The -d argument.
	bool noBackend; ///< The -S argument.
	bool noLink; ///< The -c argument
	bool emitBitCode; ///< The --emit-bitcode argument.
	bool noCatch; ///< The --no-catch argument.
	bool internalDebug; ///< The --internal-dbg argument.
	bool noStdLib; ///< The --no-stdlib argument.

	Platform platform;
	Arch arch;

	string linker; ///< The --linker argument

	string outputFile;
	string[] includePaths; ///< The -I arguments.

	string[] libraryPaths; ///< The -L arguements.
	string[] libraryFiles; ///< The -l arguments.

	string[] stdFiles; ///< The --stdlib-file arguements.
	string[] stdIncludePaths; ///< The --stdlib-I arguments.

private:
	/// If the ident exists and is true, it's set, if false it's reserved.
	bool[string] mVersionIdentifiers;
	/// If the ident exists, it's set.
	bool[string] mDebugIdentifiers;

public:
	this()
	{
		setDefaultVersionIdentifiers();
	}

	void setVersionsFromOptions()
	{
		final switch (platform) with (Platform) {
		case MinGW:
			setVersionIdentifier("Windows");
			setVersionIdentifier("MinGW");
			break;
		case Linux:
			setVersionIdentifier("Linux");
			setVersionIdentifier("Posix");
			break;
		case OSX:
			setVersionIdentifier("OSX");
			setVersionIdentifier("Posix");
			break;
		}

		final switch (arch) with (Arch) {
		case X86:
			setVersionIdentifier("X86");
			setVersionIdentifier("LittleEndian");
			setVersionIdentifier("V_P32");
			break;
		case X86_64:
			setVersionIdentifier("X86_64");
			setVersionIdentifier("LittleEndian");
			setVersionIdentifier("V_P64");
			break;
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

	final ir.PrimitiveType getSizeT(Location loc)
	{
		ir.PrimitiveType pt;
		if (isVersionSet("V_P64")) {
			pt = new ir.PrimitiveType(ir.PrimitiveType.Kind.Ulong);
		} else {
			pt = new ir.PrimitiveType(ir.PrimitiveType.Kind.Uint);
		}
		pt.location = loc;
		return pt;
	}

private:
	final void setDefaultVersionIdentifiers()
	{
		setVersionIdentifier("Volt");
		setVersionIdentifier("all");

		reserveVersionIdentifier("none");
	}

	/// Marks an identifier as unable to be set. Doesn't set the identifier.
	final void reserveVersionIdentifier(string ident)
	{
		mVersionIdentifiers[ident] = false;
	}
}

unittest
{
	auto settings = new Settings();
	assert(!settings.isVersionSet("none"));
	assert(settings.isVersionSet("all"));
	settings.setVersionIdentifier("foo");
	assert(settings.isVersionSet("foo"));
	assert(!settings.isDebugSet("foo"));
	settings.setDebugIdentifier("foo");
	assert(settings.isDebugSet("foo"));

	try {
		settings.setVersionIdentifier("none");
		assert(false);
	} catch (Exception e) {
	}
}
