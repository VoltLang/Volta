// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module main;

import std.stdio : File, writeln, writefln;
import std.string : chomp, toLower;
version (Windows) {
	import std.file : SpanMode, dirEntries;
	import std.path : baseName, dirName;
}

import volt.license;
import volt.interfaces;
import volt.controller;
import volt.util.path;


int main(string[] args)
{
	string[] files;
	auto cmd = args[0];
	args = args[1 .. $];

	auto settings = new Settings(getExecDir());
	setDefault(settings);

	if (!handleArgs(getConfigLines(), files, settings))
		return 0;

	if (!handleArgs(args, files, settings))
		return 0;

	settings.processConfigs();

	if (files.length == 0) {
		writefln("%s: no input files", cmd);
		return 0;
	}

	auto vc = new VoltController(settings);
	vc.addFiles(files);
	int ret = vc.compile();
	vc.close();

	return ret;
}

bool handleArgs(string[] args, ref string[] files, Settings settings)
{
	void delegate(string) argHandler;
	int i;

	// Handlers.
	void outputFile(string file) {
		settings.outputFile = file;
	}

	void includePath(string path) {
		settings.includePaths ~= path;
	}

	void versionIdentifier(string ident) {
		settings.setVersionIdentifier(ident);
	}

	void libraryFile(string file) {
		settings.libraryFiles ~= file;
	}

	void libraryPath(string path) {
		settings.libraryPaths ~= path;
	}

	void arch(string a) {
		switch (toLower(a)) {
		case "x86":
			settings.arch = Arch.X86;
			break;
		case "x86_64":
			settings.arch = Arch.X86_64;
			break;
		case "le32":
			settings.arch = Arch.LE32;
			break;
		default:
			writefln("unknown arch \"%s\"", a);
		}
	}

	void platform(string p) {
		switch (toLower(p)) {
		case "mingw":
			settings.platform = Platform.MinGW;
			break;
		case "linux":
			settings.platform = Platform.Linux;
			break;
		case "osx":
			settings.platform = Platform.OSX;
			break;
		case "emscripten":
			settings.platform = Platform.EMSCRIPTEN;
			settings.arch = Arch.LE32;
			break;
		default:
			writefln("unknown platform \"%s\"", p);
		}
	}

	void linker(string l) {
		settings.linker = l;
	}

	void stdFile(string file) {
		settings.stdFiles ~= file;
	}

	void stdIncludePath(string path) {
		settings.stdIncludePaths ~= path;
	}

	foreach(arg; args)  {
		if (argHandler !is null) {
			argHandler(arg);
			argHandler = null;
			continue;
		}

		// Handle @file.txt arguments.
		if (arg.length > 0 && arg[0] == '@') {
			string[] lines;
			if (!getLinesFromFile(arg[1 .. $], lines)) {
				writefln("can not find file \"%s\"", arg[1 .. $]);
				return false;
			}

			if (!handleArgs(lines, files, settings))
				return false;

			continue;
		}

		switch (arg) {
		case "--help", "-h":
			return printUsage();
		case "-license", "--license":
			return printLicense();
		case "-D":
			argHandler = &versionIdentifier;
			continue;
		case "-o":
			argHandler = &outputFile;
			continue;
		case "-I":
			argHandler = &includePath;
			continue;
		case "-L":
			argHandler = &libraryPath;
			continue;
		case "-l":
			argHandler = &libraryFile;
			continue;
		case "-w":
			settings.warningsEnabled = true;
			continue;
		case "-d":
			settings.debugEnabled = true;
			continue;
		case "-c":
			settings.noLink = true;
			continue;
		case "-E":
			settings.removeConditionalsOnly = true;
			settings.noBackend = true;
			continue;
		case "--arch":
			argHandler = &arch;
			continue;
		case "--platform":
			argHandler = &platform;
			continue;
		case "--linker":
			argHandler = &linker;
			continue;
		case "--emit-bitcode":
			settings.emitBitCode = true;
			continue;
		case "--no-backend":
		case "-S":
			settings.noBackend = true;
			continue;
		case "--no-catch":
			settings.noCatch = true;
			continue;
		case "--internal-dbg":
			settings.internalDebug = true;
			continue;
		case "--no-stdlib":
			settings.noStdLib = true;
			continue;
		case "--stdlib-file":
			argHandler = &stdFile;
			continue;
		case "--stdlib-I":
			argHandler = &stdIncludePath;
			continue;
		case "--simple-trace":
			settings.simpleTrace = true;
			continue;
		default:
		}

		version (Windows) {
			auto barg = baseName(arg);
			if (barg.length > 2 && barg[0 .. 2] == "*.") {
				foreach (file; dirEntries(dirName(arg), barg, SpanMode.shallow)) {
					files ~= file;
				}
				continue;
			}
		}

		files ~= arg;
	}

	return true;
}

string[] getConfigLines()
{
	string[] lines;
	string file = getExecDir() ~ dirSeparator ~ "volt.conf";
	getLinesFromFile(file, lines);
	return lines;
}

bool getLinesFromFile(string file, ref string[] lines)
{
	try {
		auto f = File(file);
		foreach(line; f.byLine) {
			if (line.length > 0 && line[0] != '#') {
				lines ~= chomp(line).idup;
			}
		}
	} catch {
		return false;
	}
	return true;
}

void setDefault(Settings settings)
{
	// Only MinGW is supported.
	version (Windows) {
		settings.platform = Platform.MinGW;
	} else version (linux) {
		settings.platform = Platform.Linux;
	} else version (OSX) {
		settings.platform = Platform.OSX;
	} else {
		static assert(false);
	}

	version (X86) {
		settings.arch = Arch.X86;
	} else version (X86_64) {
		settings.arch = Arch.X86_64;
	} else {
		static assert(false);
	}
}

bool printUsage()
{
	writefln("usage: volt [options] [source files]");
	writefln("\t-h,--help       Print this message and quit.");
	writefln("\t--license       Print license information and quit.");
	writefln("\t-o outputname   Set output to outputname.");
	writefln("\t-I path         Add a include path.");
	writefln("\t-L path         Add a library path.");
	writefln("\t-l path         Add a library.");
	writefln("\t-D ident        Define a new version flag");
	writefln("\t-w              Enable warnings.");
	writefln("\t-d              Compile in debug mode.");
	writefln("\t-c              Compile only, do not link.");
	writefln("\t-E              Only perform conditional removal (implies -S).");
	writefln("\t--simple-trace  Print the name of functions to stdout as they're run.");
	writeln();
	writefln("\t--arch          Select processer architecture: 'x86', 'x86_64', 'le32'");
	writefln("\t--platform      Select platform: 'mingw', 'linux', 'osx', 'emscripten'");
	writeln();
	writefln("\t--linker linker Linking program to use for linking.");
	writefln("\t--emit-bitcode  Emit LLVM bitcode (implies -c).");
	writefln("\t-S,--no-backend Stop compilation before the backend.");
	writefln("\t--no-catch      For compiler debugging purposes.");
	writefln("\t--internal-dbg  Enables internal debug printing.");
	writeln();
	writefln("\t--no-stdlib     Don't include any stdlib (from config or arguments)");
	writefln("\t--stdlib-I      Apply this include before any other -I");
	writefln("\t                (ignored if --no-stdlib was given)");
	writefln("\t--stdlib-file   Apply this file first but only when linking");
	writefln("\t                (ignored if --no-stdlib was given)");
	return false;
}

bool printLicense()
{
	foreach(license; licenseArray)
		writefln(license);
	return false;
}

