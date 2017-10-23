// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.arg;

import watt.text.string : indexOf, replace;
import watt.text.format : format;
import watt.path : dirSeparator, baseName, dirName;
import watt.conv : toLower;
import watt.io.file : searchDir;

import volt.errors;
import volt.interfaces;


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
		identStr = "Volta 0.0.1";
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
}

class Arg
{
public:
	enum Conditional
	{
		None = 0x0,
		Std = 0x1,
		Arch = 0x2,
		Platform = 0x4,
	}

	enum Kind
	{
		File,

		Identifier,
		IncludePath,
		SrcPath,
		Warnings,
		PreprocessOnly,  //!< -E
		CompileOnly,     //!< -S
		MissingDeps,     //!< --missing
		ImportAsSrc,     //!< --import-as-src

		Debug,           //!< --debug
		Release,         //!< --release
		DebugSimpleTrace,

		Dep,             //!< --dep
		Output,

		EmitLLVM,        //!< --emit-llvm
		EmitBitcode,     //!< --emit-bitcode (depricated)

		NoLink,

		CCompiler,
		CCompilerArg,

		LD,
		LDArg,

		Link,
		LinkArg,

		Clang,
		ClangArg,

		LLVMAr,
		LLVMArArg,

		Linker,
		LinkerArg,

		LibraryPath,
		LibraryName,

		FrameworkPath,
		FrameworkName,

		StringImportPath,

		JSONOutput,

		PerfOutput,

		InternalDiff,
		InternalPerf,
		InternalDebug,
		InternalNoCatch, //< --no-catch
	}

	string arg;

	int condArch;
	int condPlatform;

	Kind kind;
	Conditional cond;

public:
	this(Kind kind)
	{
		this.kind = kind;
	}

	this(string arg, Kind kind)
	{
		this.arg = arg;
		this.kind = kind;
	}
}

void filterArgs(Arg[] args, ref string[] files, VersionSet ver, Settings settings)
{
	foreach (arg; args) {
		if (arg.cond & Arg.Conditional.Std &&
		    settings.noStdLib) {
			continue;
		}

		if (arg.cond & Arg.Conditional.Arch &&
		    !(arg.condArch & (1 << settings.arch))) {
			continue;
		}

		if (arg.cond & Arg.Conditional.Platform &&
		    !(arg.condPlatform & (1 << settings.platform))) {
			continue;
		}

		final switch (arg.kind) with (Arg.Kind) {
		case File:
			auto barg = baseName(arg.arg);
			void addFile(string s) {
				files ~= s;
			}

			if (barg.length > 2 && barg[0 .. 2] == "*.") {
				version (Volt) searchDir(dirName(arg.arg), barg, addFile);
				else searchDir(dirName(arg.arg), barg, &addFile);
				continue;
			}

			files ~= arg.arg;
			break;

		case Identifier:
			ver.setVersionIdentifier(arg.arg);
			break;
		case IncludePath:
			settings.includePaths ~= arg.arg;
			break;
		case SrcPath:
			settings.srcIncludePaths ~= arg.arg;
			break;
		case Warnings:
			settings.warningsEnabled = true;
			break;
		case PreprocessOnly:
			settings.removeConditionalsOnly = true;
			settings.noBackend = true; // TODO needed?
			break;
		case CompileOnly:
			settings.noBackend = true;
			break;
		case MissingDeps:
			settings.missingDeps = true;
			break;
		case ImportAsSrc:
			settings.importAsSrc ~= arg.arg;
			break;

		case Debug:
			ver.debugEnabled = true;
			break;
		case Release:
			ver.debugEnabled = false;
			break;
		case DebugSimpleTrace:
			settings.simpleTrace = true;
			break;

		case Dep:
			settings.depFile = arg.arg;
			break;
		case Output:
			settings.outputFile = arg.arg;
			break;

		case EmitLLVM:
			settings.emitLLVM = true;
			break;
		case EmitBitcode:
			settings.noLink = true;
			settings.emitLLVM = true;
			break;

		case NoLink:
			settings.noLink = true;
			break;

		case CCompiler:
			settings.cc = arg.arg;
			break;
		case CCompilerArg:
			settings.xcc ~= arg.arg;
			break;
		case LD:
			settings.ld = arg.arg;
			break;
		case LDArg:
			settings.xld ~= arg.arg;
			break;
		case Link:
			settings.link = arg.arg;
			break;
		case LinkArg:
			settings.xlink ~= arg.arg;
			break;
		case Clang:
			settings.clang = arg.arg;
			break;
		case ClangArg:
			settings.xclang ~= arg.arg;
			break;
		case LLVMAr:
			settings.llvmAr = arg.arg;
			break;
		case LLVMArArg:
			settings.xllvmAr ~= arg.arg;
			break;
		case Linker:
			settings.linker = arg.arg;
			break;
		case LinkerArg:
			settings.xlinker ~= arg.arg;
			break;
		case LibraryPath:
			settings.libraryPaths ~= arg.arg;
			break;
		case LibraryName:
			settings.libraryFiles ~= arg.arg;
			break;
		case FrameworkPath:
			settings.frameworkPaths ~= arg.arg;
			break;
		case FrameworkName:
			settings.frameworkNames ~= arg.arg;
			break;
		case StringImportPath:
			settings.stringImportPaths ~= arg.arg;
			break;
		case JSONOutput:
			settings.jsonOutput = arg.arg;
			break;
		case PerfOutput:
			settings.perfOutput = arg.arg;
			break;

		case InternalDiff:
			settings.internalDiff = true;
			break;
		case InternalPerf:
			settings.perfOutput = "perf.cvs";
			break;
		case InternalDebug:
			settings.internalDebug = true;
			break;
		case InternalNoCatch:
			settings.noCatch = true;
			break;
		}
	}
}

Arch parseArch(string a)
{
	switch (toLower(a)) {
	case "x86":
		return Arch.X86;
	case "x86_64":
		return Arch.X86_64;
	default:
		throw makeUnknownArch(a);
	}
}

Platform parsePlatform(string p, out CRuntime cRuntime)
{
	switch (toLower(p)) {
	case "metal":
		cRuntime = CRuntime.None;
		return Platform.Metal;
	case "mingw":
		cRuntime = CRuntime.MinGW;
		return Platform.MinGW;
	case "msvc":
		cRuntime = CRuntime.Microsoft;
		return Platform.MSVC;
	case "linux", "linux-glibc":
		cRuntime = CRuntime.Glibc;
		return Platform.Linux;
	case "linux-none":
		cRuntime = CRuntime.None;
		return Platform.Linux;
	case "osx":
		cRuntime = CRuntime.Darwin;
		return Platform.OSX;
	default:
		throw makeUnknownPlatform(p);
	}
}
