// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.arg;

import watt.text.format : format;
import watt.path : dirSeparator, baseName, dirName;
import watt.conv : toLower;
import watt.io.file : searchDir;

import volt.errors;
import volt.interfaces;


// Hack.
static bool doPerfPrint;

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
		Warnings,
		PreprocessOnly,  ///< -E
		CompileOnly,     ///< -S

		Debug,
		DebugSimpleTrace,

		Output,

		EmitBitcode,     ///< --emit-bitcode

		NoLink,

		Linker,
		LinkerArg,

		LibraryPath,
		LibraryName,

		FrameworkPath,
		FrameworkName,

		DocDo,
		DocDir,
		DocOutput,

		JSONDo,
		JSONOutput,

		InternalD,
		InternalDiff,
		InternalPerf,
		InternalDebug,
		InternalNoCatch, ///< --no-catch
	}

	string arg;

	Arch condArch;
	Platform condPlatform;

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
		    settings.arch != arg.condArch) {
			continue;
		}

		if (arg.cond & Arg.Conditional.Platform &&
		    settings.platform != arg.condPlatform) {
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

			// Needed because we want to filter out .bc files.
			if (arg.cond & Arg.Conditional.Std) {
				settings.stdFiles ~= arg.arg;
			} else {
				files ~= arg.arg;
			}
			break;

		case Identifier:
			ver.setVersionIdentifier(arg.arg);
			break;
		case IncludePath:
			settings.includePaths ~= arg.arg;
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

		case Debug:
			ver.debugEnabled = true;
			break;
		case DebugSimpleTrace:
			settings.simpleTrace = true;
			break;

		case Output:
			settings.outputFile = arg.arg;
			break;

		case EmitBitcode:
			settings.emitBitcode = true;
			break;

		case NoLink:
			settings.noLink = true;
			break;

		case Linker:
			settings.linker = arg.arg;
			break;
		case LinkerArg:
			settings.xLinker ~= arg.arg;
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

		case JSONDo:
			settings.writeJson = true;
			break;
		case JSONOutput:
			settings.writeJson = true;
			settings.jsonOutput = arg.arg;
			break;
		case DocDo:
			settings.writeDocs = true;
			break;
		case DocDir:
			settings.writeDocs = true;
			settings.docDir = arg.arg;
			break;
		case DocOutput:
			settings.writeDocs = true;
			settings.docOutput = arg.arg;
			break;

		case InternalD:
			settings.internalD = true;
			break;
		case InternalDiff:
			settings.internalDiff = true;
			break;
		case InternalPerf:
			doPerfPrint = true;
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
	case "le32":
		return Arch.LE32;
	default:
		throw makeUnknownArch(a);
	}
}

Platform parsePlatform(string p)
{
	switch (toLower(p)) {
	case "mingw":
		return Platform.MinGW;
	case "msvc":
		return Platform.MSVC;
	case "linux":
		return Platform.Linux;
	case "osx":
		return Platform.OSX;
	case "emscripten":
		return Platform.EMSCRIPTEN;
	default:
		throw makeUnknownPlatform(p);
	}
}
