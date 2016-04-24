// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module main;

import watt.path : getExecDir, dirSeparator, baseName, dirName;
import watt.conv : toLower;
import watt.io.std : writefln;
import watt.io.file : exists, read, searchDir;
import watt.text.string : splitLines;

import volt.arg;
import volt.license;
import volt.interfaces;
import volt.driver;
import volt.util.path;
import volt.util.perf : Perf, perf;


int main(string[] strArgs)
{
	Settings settings;
	perf.init();
	scope (exit) {
		perf.close();
		string name = "N/A";
		string file;
		if (settings !is null) {
			name = settings.getOutput(name);
			file = settings.perfOutput;
		}
		if (file !is null) {
			perf.print(file, name);
		}
	}

	auto cmd = strArgs[0];
	strArgs = strArgs[1 .. $];

	auto ver = new VersionSet();
	settings = new Settings(cmd, getExecDir());
	setDefault(settings);


	// Get a list of arguments.
	Arg[] args;
	string[] files;
	try {

		if (!handleArgs(getConfigLines(), args, ver, settings)) {
			return 0;
		}

		if (!handleArgs(strArgs, args, ver, settings)) {
			return 0;
		}

		filterArgs(args, files, ver, settings);

		if (!checkArgs(files, settings)) {
			return 0;
		}

	} catch (Exception e) {
		writefln(e.msg);
		return 0;
	}

	settings.processConfigs(ver);
	settings.replaceMacros();

	auto vc = new VoltDriver(ver, settings);
	vc.addFiles(files);
	int ret = vc.compile();
	vc.close();

	return ret;
}

bool checkArgs(string[] files, Settings settings)
{
	if (files.length > 1 && settings.docOutput.length > 0) {
		writefln("-do flag incompatible with multiple modules");
		return false;
	}

	if (files.length == 0) {
		writefln("%s: no input files", settings.execCmd);
		return false;
	}

	return true;
}

struct ArgLooper
{
private:
	size_t mI;
	string[] mArgs;

public:
	void set(string[] args)
	{
		this.mArgs = args;
		this.mI = 0;
	}

	string next()
	{
		if (mI >= mArgs.length) {
			throw new Exception("missing argument");
		}
		return mArgs[mI++];
	}

	string nextOrNull()
	{
		if (mI >= mArgs.length) {
			return null;
		}
		return mArgs[mI++];
	}
}

bool handleArgs(string[] strArgs, ref Arg[] args, VersionSet ver, Settings settings)
{
	ArgLooper looper;
	looper.set(strArgs);

	Arg.Conditional cond;
	int condPlatform;
	int condArch;

	void applyCond(Arg arg) {
		if (cond == Arg.Conditional.None) {
			return;
		}
		arg.condPlatform = condPlatform;
		arg.condArch = condArch;
		arg.cond = cond;
		condPlatform = 0;
		condArch = 0;
		cond = Arg.Conditional.None;
	}

	void setCondP(Platform platform) {
		cond |= Arg.Conditional.Platform;
		condPlatform |= 1 << platform;
	}

	void setCondA(Arch arch) {
		cond |= Arg.Conditional.Arch;
		condArch |= 1 << arch;
	}

	void libraryName(string name) {
		auto arg = new Arg(name, Arg.Kind.LibraryName);
		applyCond(arg);
		args ~= arg;
	}

	void libraryPath(string path) {
		auto arg = new Arg(path, Arg.Kind.LibraryPath);
		applyCond(arg);
		args ~= arg;
	}

	Arg makeArgFile(string file) {
		auto arg = new Arg(file, Arg.Kind.File);
		applyCond(arg);
		args ~= arg;
		return arg;
	}

	Arg makeArgNext(Arg.Kind kind) {
		auto n = looper.next();
		auto arg = new Arg(n, kind);
		applyCond(arg);
		args ~= arg;
		return arg;
	}

	Arg makeArg(Arg.Kind kind) {
		auto arg = new Arg(kind);
		applyCond(arg);
		args ~= arg;
		return arg;
	}

	for (string arg = looper.nextOrNull();
	     arg !is null;
	     arg = looper.nextOrNull()) {

		// Handle @file.txt arguments.
		if (arg.length > 0 && arg[0] == '@') {
			string[] lines;
			if (!getLinesFromFile(arg[1 .. $], lines)) {
				writefln("can not find file \"%s\"", arg[1 .. $]);
				return false;
			}

			if (!handleArgs(lines, args, ver, settings))
				return false;

			continue;
		}

		switch (arg) with (Arg.Kind) {
		// Special cased.
		case "--help", "-h":
			return printUsage();
		case "-license", "--license":
			return printLicense();
		case "--arch":
			settings.arch = parseArch(looper.next());
			continue;
		case "--platform":
			settings.platform = parsePlatform(looper.next());
			continue;
		case "--no-stdlib":
			settings.noStdLib = true;
			continue;

		// Regular args.
		case "-D":
			makeArgNext(Identifier);
			continue;
		case "-o":
			makeArgNext(Output);
			continue;
		case "-I":
			makeArgNext(IncludePath);
			continue;
		case "-L":
			libraryPath(looper.next());
			continue;
		case "-l":
			libraryName(looper.next());
			continue;
		case "-F":
			makeArgNext(FrameworkPath);
			continue;
		case "-framework", "--framework":
			makeArgNext(FrameworkName);
			continue;
		case "--doc":
			makeArg(DocDo);
			continue;
		case "--doc-dir":
			makeArgNext(DocDir);
			continue;
		case "-do":
			makeArgNext(DocOutput);
			continue;
		case "--json":
			makeArg(JSONDo);
			continue;
		case "-jo":
			makeArgNext(JSONOutput);
			continue;
		case "-cc", "--cc":
			makeArgNext(CCompiler);
			continue;
		case "-Xcc", "--Xcc":
			makeArgNext(CCompilerArg);
			continue;
		case "-ld", "--ld":
			makeArgNext(LD);
			continue;
		case "-Xld", "--Xld":
			makeArgNext(LDArg);
			continue;
		case "-link", "--link":
			makeArgNext(Link);
			continue;
		case "-Xlink", "--Xlink":
			makeArgNext(LinkArg);
			continue;
		case "-linker", "--linker":
			makeArgNext(Linker);
			continue;
		case "-Xlinker", "--Xlinker":
			makeArgNext(LinkerArg);
			continue;
		case "--internal-d":
			makeArg(InternalD);
			continue;
		case "--internal-dbg":
			makeArg(InternalDebug);
			continue;
		case "--internal-perf":
			makeArg(InternalPerf);
			continue;
		case "--internal-diff":
			makeArg(InternalDiff);
			continue;
		case "--perf-output":
			makeArgNext(PerfOutput);
			continue;
		case "-w":
			makeArg(Warnings);
			continue;
		case "-d":
			makeArg(Debug);
			continue;
		case "-c":
			makeArg(NoLink);
			continue;
		case "-E":
			makeArg(PreprocessOnly);
			continue;
		case "-J":
			makeArgNext(StringImportPath);
			continue;
		case "--emit-bitcode":
			makeArg(EmitBitcode);
			continue;
		case "--no-backend", "-S":
			makeArg(CompileOnly);
			continue;
		case "--no-catch":
			makeArg(InternalNoCatch);
			continue;
		case "--simple-trace":
			makeArg(DebugSimpleTrace);
			continue;
		case "--if-stdlib":
			cond |= Arg.Conditional.Std;
			continue;
		case "--if-linux": setCondP(Platform.Linux); continue;
		case "--if-osx": setCondP(Platform.OSX); continue;
		case "--if-msvc": setCondP(Platform.MSVC); continue;
		case "--if-mingw": setCondP(Platform.MinGW); continue;
		case "--if-metal": setCondP(Platform.Metal); continue;
		case "--if-x86": setCondA(Arch.X86); continue;
		case "--if-x86_64": setCondA(Arch.X86_64); continue;
		case "--if-le32": setCondA(Arch.LE32); continue;

		// Handle combined arguments.
		default:
			if (arg.length > 2) {
				switch (arg[0 .. 2]) {
				case "-l":
					libraryName(arg[2 .. $]);
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

		if (arg.length > 1 &&
		    arg[0] == '-') {
			throw new Exception("Unknown argument: '" ~ arg ~ "'");
		}
		makeArgFile(arg);
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
	writefln("\t-J path          Define a path for string import to look for files.");
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
	writefln("\t--platform       Select platform: 'mingw', 'linux', 'osx', 'msvc', 'metal'");
	writefln("");
	writefln("\t--cc compiler    C compiler to use for linking.");
	writefln("\t--Xcc arg        Add an argument when invoking the cc linker.");
	writefln("\t--ld linker      LD compatible program to use for linking.");
	writefln("\t--Xld arg        Add an argument when invoking the linker.");
	writefln("\t--link msvc      MSVC link program to use for linking.");
	writefln("\t--Xlink arg      Add an argument when invoking MSVC link.");
	writefln("\t--emit-bitcode   Emit LLVM bitcode (implies -c).");
	writefln("\t-S,--no-backend  Stop compilation before the backend.");
	writefln("\t--no-catch       For compiler debugging purposes.");
	writefln("");
	writefln("\t--no-stdlib      Don't include any stdlib (from config or arguments)");
	writefln("");
	writefln("\t--if-stdlib      Only apply the following argument if using stdlib.");
	writefln("\t--if-'platform'  Only apply the following argument if platform is this.");
	writefln("\t--if-'arch'      Only apply the following argument if arch is this.");
	writefln("\t                 (The if args are cumulative so that multiple");
	writefln("\t                  arch & platforms or togther, like so:");
	writefln("\t                  ('arch' || 'arch') && 'platform' && 'stdlib')");
	writefln("");
	writefln("\t--perf-output    Enables compiler profiling and sets output file");
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
