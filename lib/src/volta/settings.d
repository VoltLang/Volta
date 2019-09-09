/*#D*/
// Copyright 2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module volta.settings;

import watt.text.string;
import volta.interfaces;
import license = volta.license;


/*!
 * Holds a set of compiler settings.
 *
 * Things like import paths, and so on.
 */
final class Settings
{
public:
	bool warningsEnabled; //!< The -w argument.
	bool noBackend; //!< The -S argument.
	bool noLink; //!< The -c argument
	bool emitLLVM; //!< The --emit-llvm argument.
	bool noCatch; //!< The --no-catch argument.
	bool noStdLib; //!< The --no-stdlib argument.
	bool removeConditionalsOnly; //!< The -E argument.
	bool simpleTrace; //!< The --simple-trace argument.
	bool internalDiff; //!< The --internal-diff argument.
	bool internalDebug; //!< The --internal-dbg argument.
	bool missingDeps; //!< The --missing argument;

	Platform platform;
	Arch arch;
	CRuntime cRuntime;

	string identStr; //!< Compiler identifier string.

	string execCmd; //!< How where we launched.
	string execDir; //!< Set on create.
	string platformStr; //!< Derived from platform.
	string archStr; //!< Derived from arch.

	string cc; //!< The --cc argument.
	string[] xcc; //!< Arguments to cc, the --Xcc argument(s).

	string ld; //!< The --ld argument.
	string[] xld; //!< The --Xld argument(s).

	string link; //!< The --link argument.
	string[] xlink; //!< The --Xlink argument(s).

	string clang; //!< The --clang argument.
	string[] xclang; //!< The --Xclang argument(s).

	string llvmAr; //!< The --llvm-ar argument.
	string[] xllvmAr; //!< The --Xllvm-ar argument(s).

	string linker; //!< The --linker argument
	string[] xlinker; //!< Arguments to the linker, the -Xlinker argument(s).

	string depFile;
	string outputFile;

	string[] importAsSrc; //!< The --import-as-src command.

	string[] includePaths; //!< The -I arguments.
	string[] srcIncludePaths; //!< The -src-I arguments.

	string[] libraryPaths; //!< The -L arguments.
	string[] libraryFiles; //!< The -l arguments.

	string[] frameworkPaths; //!< The -F arguments.
	string[] frameworkNames; //!< The --framework arguments.

	string[] stringImportPaths; //!< The -J arguments.

	string jsonOutput; //!< The -jo argument.

	string perfOutput; //!< The --perf-output argument.


public:
	this(string cmd, string execDir)
	{
		this.execCmd = cmd;
		this.execDir = execDir;
	}

	final void processConfigs()
	{
		identStr = license.ident;
		setStrs();
		replaceMacros();
	}

	void setStrs()
	{
		final switch (platform) with (Platform) {
		case MinGW: platformStr = "mingw"; break;
		case MSVC: platformStr = "msvc"; break;
		case Linux:
			final switch (cRuntime) with (CRuntime) {
			case None: platformStr = "linux-none"; break;
			case Glibc: platformStr = "linux-glibc"; break;
			case CRuntime.MinGW, Microsoft, Darwin: assert(false);
			}
			break;
		case OSX: platformStr = "osx"; break;
		case Metal: platformStr = "metal"; break;
		}
		final switch (arch) with (Arch) {
		case ARMHF: archStr = "armhf"; break;
		case AArch64: archStr = "aarch64"; break;
		case X86: archStr = "x86"; break;
		case X86_64: archStr = "x86_64"; break;
		}
	}

	final void replaceMacros()
	{
		foreach (ref f; includePaths) {
			f = replaceEscapes(f);
		}
		foreach (ref f; srcIncludePaths) {
			f = replaceEscapes(f);
		}
		foreach (ref f; libraryPaths) {
			f = replaceEscapes(f);
		}
		foreach (ref f; libraryFiles) {
			f = replaceEscapes(f);
		}
	}

	final string replaceEscapes(string file)
	{
		// @todo enum *
		string e = "%@execdir%";
		string a = "%@arch%";
		string p = "%@platform%";
		ptrdiff_t ret;

		ret = indexOf(file, e);
		if (ret != -1) {
			file = replace(file, e, execDir);
		}
		ret = indexOf(file, a);
		if (ret != -1) {
			file = replace(file, a, archStr);
		}
		ret = indexOf(file, p);
		if (ret != -1) {
			file = replace(file, p, platformStr);
		}

		return file;
	}

	final void setDefault()
	{
		version (Windows) {
			platform = Platform.MSVC;
			cRuntime = CRuntime.Microsoft;
		} else version (linux) { // D2
			platform = Platform.Linux;
			cRuntime = CRuntime.Glibc;
		} else version (Linux) { // Volt
			platform = Platform.Linux;
			cRuntime = CRuntime.Glibc;
		} else version (OSX) {
			platform = Platform.OSX;
			cRuntime = CRuntime.Darwin;
		} else {
			static assert(false);
		}

		version (X86) {
			arch = Arch.X86;
		} else version (X86_64) {
			arch = Arch.X86_64;
		} else version (ARM) {
			arch = Arch.ARMHF;
		} else version (ARMHF) {
			arch = Arch.ARMHF;
		} else version (AArch64) {
			arch = Arch.X86_64;
		} else {
			static assert(false);
		}
	}
}
