/*#D*/
// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.interfaces;

import ir = volta.ir;
import volta.ir.location;


/*!
 * @defgroup ifaces Interfaces
 * @brief Common interfaces between various parts of the compiler.
 *
 */

/*!
 * Interface for communicating error conditions to the user.
 *
 * Methods may terminate.
 */
interface ErrorSink
{
	void onWarning(string msg, string file, int line);
	void onWarning(ref in ir.Location loc, string msg, string file, int line);
	void onError(string msg, string file, int line);
	void onError(ref in ir.Location loc, string msg, string file, int line);
	void onPanic(string msg, string file, int line);
	void onPanic(ref in ir.Location loc, string msg, string file, int line);
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
 
/*!
 * Each of these listed architectures corresponds
 * to a Version identifier.
 */
enum Arch
{
	X86,
	X86_64,
}

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
 * A set of version/debug identifiers.
 *
 * @ingroup ifaces
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
	final bool setVersionIdentifierIfNotReserved(string ident)
	{
		if (auto p = ident in mVersionIdentifiers) {
			if (!(*p)) {
				return false;
			}
		}
		mVersionIdentifiers[ident] = true;
		return true;
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
 * @ingroup passes ifaces
 */
interface Pass
{
	//! Free resources.
	void close();

	//! Run the pass on the given module.
	void transform(ir.Module m);
}
