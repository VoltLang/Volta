// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module main;

version (Windows) {
	import watt.io.file : searchDir;
	import watt.path : baseName, dirName;
}

import watt.path : getExecDir, dirSeparator;
import watt.conv : toLower;
import watt.io.std : writefln;
import watt.io.file : exists, read;
import watt.text.string : splitLines;

import volt.license;
import volt.interfaces;
import volt.driver;
import volt.util.path;
import volt.util.perf : perf;

static bool doPerfPrint;

int main(string[] args)
{
	perf.tag("setup");
	scope (exit) {
		perf.tag("done");
		if (doPerfPrint) {
			perf.print();
		}
	}

	string[] files;
	auto cmd = args[0];
	args = args[1 .. $];

	auto ver = new VersionSet();
	auto settings = new Settings(getExecDir());
	setDefault(settings);
	version (Volt) settings.noBackend = true;

	if (!handleArgs(getConfigLines(), files, ver, settings)) {
		return 0;
	}

	if (!handleArgs(args, files, ver, settings)) {
		return 0;
	}

	settings.processConfigs(ver);

	if (files.length == 0) {
		writefln("%s: no input files", cmd);
		return 0;
	}

	auto vc = new VoltDriver(ver, settings);
	vc.addFiles(files);
	int ret = vc.compile();
	vc.close();

	return ret;
}

bool handleArgs(string[] args, ref string[] files, VersionSet ver, Settings settings)
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
		ver.setVersionIdentifier(ident);
	}

	void libraryFile(string file) {
		settings.libraryFiles ~= file;
	}

	void libraryPath(string path) {
		settings.libraryPaths ~= path;
	}

	void frameworkPath(string path) {
		settings.frameworkPaths ~= path;
	}

	void frameworkName(string name) {
		settings.frameworkNames ~= name;
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
		case "msvc":
			settings.platform = Platform.MSVC;
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

	void docDir(string path) {
		settings.docDir = path;
	}

	void docOutput(string path) {
		settings.docOutput = path;
	}

	void jsonOutput(string path) {
		settings.jsonOutput = path;
	}

	foreach (arg; args)  {
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

			if (!handleArgs(lines, files, ver, settings))
				return false;

			continue;
		}

		switch (arg) {
		case "--help", "-h":
			return printUsage();
		case "-license", "--license":
			return printLicense();
		case "-D":
			version (Volt) {
				argHandler = cast(typeof(argHandler))versionIdentifier;
			} else {
				argHandler = &versionIdentifier;
			}
			continue;
		case "-o":
			version (Volt) {
				argHandler = cast(typeof(argHandler))outputFile;
			} else {
				argHandler = &outputFile;
			}
			continue;
		case "-I":
			version (Volt) {
				argHandler = cast(typeof(argHandler))includePath;
			} else {
				argHandler = &includePath;
			}
			continue;
		case "-L":
			version (Volt) {
				argHandler = cast(typeof(argHandler))libraryPath;
			} else {
				argHandler = &libraryPath;
			}
			continue;
		case "-l":
			version (Volt) {
				argHandler = cast(typeof(argHandler))libraryFile;
			} else {
				argHandler = &libraryFile;
			}
			continue;
		case "-F":
			version (Volt) {
				argHandler = cast(typeof(argHandler))frameworkPath;
			} else {
				argHandler = &frameworkPath;
			}
			continue;
		case "-framework", "--framework":
			version (Volt) {
				argHandler = cast(typeof(argHandler))frameworkName;
			} else {
				argHandler = &frameworkName;
			}
			continue;
		case "-w":
			settings.warningsEnabled = true;
			continue;
		case "-d":
			ver.debugEnabled = true;
			continue;
		case "-c":
			settings.noLink = true;
			continue;
		case "-E":
			settings.removeConditionalsOnly = true;
			settings.noBackend = true;
			continue;
		case "--arch":
			version (Volt) {
				argHandler = cast(typeof(argHandler))arch;
			} else {
				argHandler = &arch;
			}
			continue;
		case "--platform":
			version (Volt) {
				argHandler = cast(typeof(argHandler))platform;
			} else {
				argHandler = &platform;
			}
			continue;
		case "--linker":
			version (Volt) {
				argHandler = cast(typeof(argHandler))linker;
			} else {
				argHandler = &linker;
			}
			continue;
		case "--emit-bitcode":
			settings.emitBitcode = true;
			continue;
		case "--no-backend":
		case "-S":
			settings.noBackend = true;
			continue;
		case "--no-catch":
			settings.noCatch = true;
			continue;
		case "--no-stdlib":
			settings.noStdLib = true;
			continue;
		case "--stdlib-file":
			version (Volt) {
				argHandler = cast(typeof(argHandler))stdFile;
			} else {
				argHandler = &stdFile;
			}
			continue;
		case "--stdlib-I":
			version (Volt) {
				argHandler = cast(typeof(argHandler))stdIncludePath;
			} else {
				argHandler = &stdIncludePath;
			}
			continue;
		case "--simple-trace":
			settings.simpleTrace = true;
			continue;
		case "--doc":
			settings.writeDocs = true;
			continue;
		case "--doc-dir":
			settings.writeDocs = true;
			version (Volt) {
				argHandler = cast(typeof(argHandler))docDir;
			} else {
				argHandler = &docDir;
			}
			continue;
		case "-do":
			settings.writeDocs = true;
			version (Volt) {
				argHandler = cast(typeof(argHandler))docOutput;
			} else {
				argHandler = &docOutput;
			}
			continue;
		case "-jo":
			settings.writeJson = true;
			version (Volt) {
				argHandler = cast(typeof(argHandler))jsonOutput;
			} else {
				argHandler = &jsonOutput;
			}
			continue;
		case "--json":
			settings.writeJson = true;
			continue;
		case "--internal-d":
			settings.internalD = true;
			continue;
		case "--internal-dbg":
			settings.internalDebug = true;
			continue;
		case "--internal-perf":
			doPerfPrint = true;
			continue;
		case "--internal-diff":
			settings.internalDiff = true;
			continue;
		default:
			if (arg.length > 2) {
				switch (arg[0 .. 2]) {
				case "-l":
					libraryFile(arg[2 .. $]);
					continue;
				case "-L":
					libraryPath(arg[2 .. $]);
					continue;
				default:
					break;
				}
			}
			break;
		}

		version (Windows) {
			auto barg = baseName(arg);
			void addFile(string s) {
				files ~= s;
			}
			if (barg.length > 2 && barg[0 .. 2] == "*.") {
				version (Volt) searchDir(dirName(arg), barg, addFile);
				else searchDir(dirName(arg), barg, &addFile);
				continue;
			}
		}

		files ~= arg;
	}

	if (files.length > 1 && settings.docOutput.length > 0) {
		writefln("-do flag incompatible with multiple modules");
		return false;
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
	if (!exists(file)) {
		return false;
	}

	auto src = cast(string) read(file);

	foreach (line; splitLines(src)) {
		if (line.length > 0 && line[0] != '#') {
			lines ~= line;
		}
	}
	return true;
}

void setDefault(Settings settings)
{
	// Only MinGW is supported.
	version (Windows) {
		settings.platform = Platform.MinGW;
	} else version (linux) { // D2
		settings.platform = Platform.Linux;
	} else version (Linux) { // Volt
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
	writefln("\t-h,--help        Print this message and quit.");
	writefln("\t--license        Print license information and quit.");
	writefln("\t-o outputname    Set output to outputname.");
	writefln("\t-I path          Add a include path.");
	writefln("\t-L path          Add a library path.");
	writefln("\t-l path          Add a library.");
	version (OSX) {
	writefln("\t-F path          Add a framework path.");
	writefln("\t--framework name Add a framework.");
	}
	writefln("\t-D ident         Define a new version flag");
	writefln("\t-w               Enable warnings.");
	writefln("\t-d               Compile in debug mode.");
	writefln("\t-c               Compile only, do not link.");
	writefln("\t-E               Only perform conditional removal (implies -S).");
	writefln("\t--simple-trace   Print the name of functions to stdout as they're run.");
	writefln("\t--doc            Write out documentation in HTML format.");
	writefln("\t--json           Write documentation in JSON format.");
	writefln("\t--doc-dir        Specify a base directory for documentation (implies --doc).");
	writefln("\t-do              Specify documentation output name (implies --doc).");
	writefln("\t-jo              Specify json output name (implies --json).");
	writefln("");
	writefln("\t--arch           Select processer architecture: 'x86', 'x86_64', 'le32'");
	writefln("\t--platform       Select platform: 'mingw', 'linux', 'osx', 'emscripten'");
	writefln("");
	writefln("\t--linker linker  Linking program to use for linking.");
	writefln("\t--emit-bitcode   Emit LLVM bitcode (implies -c).");
	writefln("\t-S,--no-backend  Stop compilation before the backend.");
	writefln("\t--no-catch       For compiler debugging purposes.");
	writefln("");
	writefln("\t--no-stdlib      Don't include any stdlib (from config or arguments)");
	writefln("\t--stdlib-I       Apply this include before any other -I");
	writefln("\t                 (ignored if --no-stdlib was given)");
	writefln("\t--stdlib-file    Apply this file first but only when linking");
	writefln("\t                 (ignored if --no-stdlib was given)");
	writefln("");
	writefln("\t--internal-d     Enables internal D friendlier rules.");
	writefln("\t--internal-dbg   Enables internal debug printing.");
	writefln("\t--internal-perf  Enables internal performance timings.");
	writefln("\t--internal-diff  Enables internal debug diff printing.");
	return false;
}

bool printLicense()
{
	foreach (license; licenseArray) {
		writefln(license);
	}
	return false;
}
