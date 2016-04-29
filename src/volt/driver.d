// Copyright © 2012-2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.driver;

import io = watt.io.std : output, error;

import watt.path : temporaryFilename, dirSeparator;
import watt.process : spawnProcess, wait;
import watt.io.file : remove, exists, read;
import watt.conv : toLower;
import watt.text.diff : diff;
import watt.text.format : format;
import watt.text.string : endsWith;

import volt.util.path;
import volt.util.perf : Accumulator, Perf, perf;
import volt.exceptions;
import volt.interfaces;
import volt.errors;
import volt.arg;
import ir = volt.ir.ir;

import volt.parser.parser;
import volt.semantic.languagepass;
import volt.llvm.backend;
import volt.util.mangledecoder;

import volt.visitor.visitor;
import volt.visitor.prettyprinter;
import volt.visitor.debugprinter;
import volt.visitor.docprinter;
import volt.visitor.jsonprinter;


/**
 * Default implementation of @link volt.interfaces.Driver Driver@endlink, replace
 * this if you wish to change the basic operation of the compiler.
 */
class VoltDriver : Driver
{
public:
	VersionSet ver;
	Settings settings;
	Frontend frontend;
	LanguagePass languagePass;
	Backend backend;

	Pass[] debugVisitors;

protected:
	bool mLinkWithLD;   // Posix/GNU
	bool mLinkWithCC;   // Posix/GNU
	bool mLinkWithLink; // MSVC
	string mCC;         // cc compatible command line (gcc/clang).
	string mLD;         // ld compatible command line (ld/lld)
	string mLink;       // MSVC Link

	string[] mIncludes;
	string[] mSrcIncludes;
	string[] mSourceFiles;
	string[] mBitcodeFiles;
	string[] mObjectFiles;

	string[] mLibraryFiles;
	string[] mLibraryPaths;

	string[] mFrameworkNames;
	string[] mFrameworkPaths;

	ir.Module[] mCommandLineModules;

	/// Temporary files created during compile.
	string[] mTemporaryFiles;

	/// Used to track if we should debug print on error.
	bool mDebugPassesRun;

	Accumulator mAccumReading;
	Accumulator mAccumParsing;

public:
	this(VersionSet ver, Settings s)
	in {
		assert(s !is null);
		assert(ver !is null);
	}
	body {
		this.ver = ver;
		this.settings = s;
		this.frontend = new Parser();

		// Timers
		mAccumReading = new Accumulator("p1-reading");
		mAccumParsing = new Accumulator("p1-parsing");


		Driver drv = this;
		languagePass = new VoltLanguagePass(drv, ver, s, frontend);

		if (!s.noBackend) {
			backend = new LlvmBackend(languagePass);
		}

		mIncludes = settings.includePaths;
		mSrcIncludes = settings.srcIncludePaths;

		mLibraryPaths = settings.libraryPaths;
		mLibraryFiles = settings.libraryFiles;

		mFrameworkNames = settings.frameworkNames;
		mFrameworkPaths = settings.frameworkPaths;

		// Should we add the standard library.
		if (!settings.emitBitcode &&
		    !settings.noLink &&
		    !settings.noStdLib) {
			foreach (file; settings.stdFiles) {
				addFile(file);
			}
		}


		if (settings.linker !is null) {
			switch (settings.platform) with (Platform) {
			case MSVC:
				mLink = settings.linker;
				mLinkWithLink = true;
				break;
			default:
				mLD = settings.linker;
				mLinkWithLD = true;
				break;
			}
		} else if (settings.ld !is null) {
			mLD = settings.ld;
			mLinkWithLD = true;
		} else if (settings.cc !is null) {
			mCC = settings.cc;
			mLinkWithCC = true;
		} else if (settings.link !is null) {
			mLink = settings.link;
			mLinkWithLink = true;
		} else {
			switch (settings.platform) with (Platform) {
			case MSVC:
				mLink = "link.exe";
				mLinkWithLink = true;
				break;
			case EMSCRIPTEN:
				mCC = "emcc";
				mLinkWithCC = true;
				break;
			default:
				mLinkWithCC = true;
				mCC = "gcc";
				break;
			}
		}

		debugVisitors ~= new DebugMarker("Running DebugPrinter:");
		debugVisitors ~= new DebugPrinter();
		debugVisitors ~= new DebugMarker("Running PrettyPrinter:");
		debugVisitors ~= new PrettyPrinter();
	}


	/*
	 *
	 * Driver functions.
	 *
	 */

	/**
	 * Retrieve a Module by its name. Returns null if none is found.
	 */
	override ir.Module loadModule(ir.QualifiedName name)
	{
		auto srcPath = pathFromQualifiedName(name, mSrcIncludes);
		auto incPath = pathFromQualifiedName(name, mIncludes);
		if (srcPath.length == 0 && incPath.length == 0) {
			return null;
		}
		if (srcPath.length > 0) {
			mSourceFiles ~= srcPath;
			auto m = loadAndParse(srcPath);
			languagePass.addModule(m);
			mCommandLineModules ~= m;
			return m;
		}
		assert(incPath.length > 0);
		return loadAndParse(incPath);
	}

	override ir.Module[] getCommandLineModules()
	{
		return mCommandLineModules;
	}

	override void close()
	{
		frontend.close();
		languagePass.close();
		if (backend !is null) {
			backend.close();
		}

		settings = null;
		frontend = null;
		languagePass = null;
		backend = null;
	}


	/*
	 *
	 * Misc functions.
	 *
	 */

	void addFile(string file)
	{
		file = settings.replaceEscapes(file);
		version (Windows) {
			// VOLT TEST.VOLT  REM Reppin' MS-DOS
			file = toLower(file);
		}

		if (endsWith(file, ".d", ".volt") > 0) {
			mSourceFiles ~= file;
		} else if (endsWith(file, ".bc")) {
			mBitcodeFiles ~= file;
		} else if (endsWith(file, ".o", ".obj")) {
			mObjectFiles ~= file;
		} else {
			auto str = format("unknown file type '%s'", file);
			throw new CompilerError(str);
		}
	}

	void addFiles(string[] files)
	{
		foreach (file; files) {
			addFile(file);
		}
	}

	int compile()
	{
		mDebugPassesRun = false;
		scope (success) {
			debugPasses();

			foreach (f; mTemporaryFiles) {
				if (f.exists()) {
					f.remove();
				}
			}

			perf.mark(Perf.Mark.EXIT);
		}

		if (settings.noCatch) {
			return intCompile();
		}

		try {
			return intCompile();
		} catch (CompilerPanic e) {
			io.error.writefln(e.msg);
			if (e.file !is null) {
				io.error.writefln("%s:%s", e.file, e.line);
			}
			return 2;
		} catch (CompilerError e) {
			io.error.writefln(e.msg);
			debug if (e.file !is null) {
				io.error.writefln("%s:%s", e.file, e.line);
			}
			return 1;
		} catch (object.Throwable t) {
			io.error.writefln("panic: %s", t.msg);
			if (t.file !is null) {
				io.error.writefln("%s:%s", t.file, t.line);
			}
			return 2;
		}

		version (Volt) assert(false);
	}

protected:
	string pathFromQualifiedName(ir.QualifiedName name, string[] includes)
	{
		string[] validPaths;
		foreach (path; includes) {
			auto paths = genPossibleFilenames(path, name.strings);

			foreach (possiblePath; paths) {
				if (exists(possiblePath)) {
					validPaths ~= possiblePath;
				}
			}
		}

		if (validPaths.length == 0) {
			return "";
		}
		if (validPaths.length > 1) {
			throw makeMultipleValidModules(name, validPaths);
		}
		return validPaths[0];
	}

	/**
	 * Loads a file and parses it.
	 */
	ir.Module loadAndParse(string file)
	{
		string src;
		{
			mAccumReading.start();
			scope (exit) mAccumReading.stop();
			src = cast(string) read(file);
		}

		mAccumParsing.start();
		scope (exit) mAccumParsing.stop();
		return frontend.parseNewFile(src, file);
	}

	int intCompile()
	{
		perf.mark(Perf.Mark.PARSING);

		// Load all modules to be compiled.
		// Don't run phase 1 on them yet.
		auto dp = new DocPrinter(languagePass);
		auto jp = new JsonPrinter(languagePass);
		foreach (file; mSourceFiles) {
			debugPrint("Parsing %s.", file);

			auto m = loadAndParse(file);
			languagePass.addModule(m);
			mCommandLineModules ~= m;

			if (settings.writeDocs) {
				dp.transform(m);
			}
		}
		if (settings.writeJson) {
			jp.transform(mCommandLineModules);
		}

		// Skip setting up the pointers incase object
		// was not loaded, after that we are done.
		if (settings.removeConditionalsOnly) {
			languagePass.phase1(mCommandLineModules);
			return 0;
		}

		// After we have loaded all of the modules
		// setup the pointers, this allows for suppling
		// a user defined object module.
		auto lp = cast(VoltLanguagePass)languagePass;
		lp.setupOneTruePointers();

		// Setup diff buffers.
		auto ppstrs = new string[](mCommandLineModules.length);
		auto dpstrs = new string[](mCommandLineModules.length);

		preDiff(mCommandLineModules, "Phase 1", ppstrs, dpstrs);
		perf.mark(Perf.Mark.PHASE1);

		// Force phase 1 to be executed on the modules.
		// This might load new modules.
		languagePass.phase1(mCommandLineModules);
		postDiff(mCommandLineModules, ppstrs, dpstrs);

		// New modules have been loaded,
		// make sure to run everthing on them.
		auto allMods = languagePass.getModules();

		preDiff(mCommandLineModules, "Phase 2", ppstrs, dpstrs);
		perf.mark(Perf.Mark.PHASE2);

		// All modules need to be run through phase2.
		languagePass.phase2(allMods);
		postDiff(mCommandLineModules, ppstrs, dpstrs);

		preDiff(mCommandLineModules, "Phase 3", ppstrs, dpstrs);
		perf.mark(Perf.Mark.PHASE3);

		// All modules need to be run through phase3.
		languagePass.phase3(allMods);
		postDiff(mCommandLineModules, ppstrs, dpstrs);

		debugPasses();

		if (settings.noBackend) {
			return 0;
		}
		perf.mark(Perf.Mark.BACKEND);

		// We will be modifing this later on,
		// but we don't want to change mBitcodeFiles.
		string[] bitcodeFiles = mBitcodeFiles;
		string subdir = getTemporarySubdirectoryName();


		foreach (m; mCommandLineModules) {
			string o = temporaryFilename(".bc", subdir);
			backend.setTarget(o, TargetType.LlvmBitcode);
			debugPrint("Backend %s.", m.name.toString());
			backend.compile(m);
			bitcodeFiles ~= o;
			mTemporaryFiles ~= o;
		}

		string bc, obj, of;

		// Setup files bc.
		if (settings.emitBitcode) {
			bc = settings.getOutput(DEFAULT_BC);
		} else {
			if (bitcodeFiles.length == 1) {
				bc = bitcodeFiles[0];
				bitcodeFiles = null;
			} else {
				bc = temporaryFilename(".bc", subdir);
				mTemporaryFiles ~= bc;
			}
		}

		// Link bitcode files.
		if (bitcodeFiles.length > 0) {
			perf.mark(Perf.Mark.BITCODE);
			linkModules(bc, bitcodeFiles);
		}

		// When outputting bitcode we are now done.
		if (settings.emitBitcode) {
			return 0;
		}

		// Setup object files and output for linking.
		if (settings.noLink) {
			obj = settings.getOutput(DEFAULT_OBJ);
		} else {
			of = settings.getOutput(DEFAULT_EXE);
			obj = temporaryFilename(".o", subdir);
			mTemporaryFiles ~= obj;
		}

		// If we are compiling on the emscripten platform ignore .o files.
		if (settings.platform == Platform.EMSCRIPTEN) {
			perf.mark(Perf.Mark.LINK);
			return emscriptenLink(mCC, bc, of);
		}

		// Native compilation, turn the bitcode into native code.
		perf.mark(Perf.Mark.ASSEMBLE);
		writeObjectFile(settings, obj, bc);

		// When not linking we are now done.
		if (settings.noLink) {
			return 0;
		}

		// And finally call the linker.
		perf.mark(Perf.Mark.LINK);
		return nativeLink(obj, of);
	}

	int nativeLink(string obj, string of)
	{
		if (mLinkWithLink) {
			return msvcLink(mLink, obj, of);
		} else if (mLinkWithLD) {
			return ccLink(mLD, false, obj, of);
		} else if (mLinkWithCC) {
			return ccLink(mCC, true, obj, of);
		} else {
			assert(false);
		}
	}

	int ccLink(string linker, bool cc, string obj, string of)
	{
		string[] args = ["-o", of];

		if (cc) {
			final switch (settings.arch) with (Arch) {
			case X86: args ~= "-m32"; break;
			case X86_64: args ~= "-m64"; break;
			case LE32: throw panic("unsupported arch with cc");
			}
		}

		foreach (objectFile; mObjectFiles ~ obj) {
			args ~= objectFile;
		}
		foreach (libraryPath; mLibraryPaths) {
			args ~= "-L" ~ libraryPath;
		}
		foreach (libraryFile; mLibraryFiles) {
			args ~= "-l" ~ libraryFile;
		}
		foreach (frameworkPath; mFrameworkPaths) {
			args ~= "-F";
			args ~= frameworkPath;
		}
		foreach (frameworkName; mFrameworkNames) {
			args ~= "-framework";
			args ~= frameworkName;
		}
		if (cc) {
			foreach (xcc; settings.xcc) {
				args ~= xcc;
			}
			foreach (xLD; settings.xld) {
				args ~= "-Xlinker";
				args ~= xLD;
			}
			foreach (xLinker; settings.xlinker) {
				args ~= "-Xlinker";
				args ~= xLinker;
			}
		} else {
			foreach (xLD; settings.xld) {
				args ~= xLD;
			}
			foreach (xLink; settings.xlinker) {
				args ~= xLink;
			}
		}

		return spawnProcess(linker, args).wait();
	}

	int msvcLink(string linker, string obj, string of)
	{
		string[] args = [
			"/MACHINE:x64",
			"/defaultlib:libcmt",
			"/defaultlib:oldnames",
			"legacy_stdio_definitions.lib",
			"/nologo",
			"/out:" ~ of];

		foreach (objectFile; mObjectFiles ~ obj) {
			args ~= objectFile;
		}
		foreach (libraryPath; mLibraryPaths) {
			args ~= "/LIBPATH:" ~ libraryPath;
		}
		foreach (libraryFile; mLibraryFiles) {
			args ~= libraryFile;
		}
		foreach (xLink; settings.xlink) {
			args ~= xLink;
		}

		// We are using msvc link directly so this is
		// linker arguments.
		foreach (xLinker; settings.xlinker) {
			args ~= xLinker;
		}

		return spawnProcess(linker, args).wait();
	}

	int emscriptenLink(string linker, string bc, string of)
	{
		string[] args = ["-o", of];
		return spawnProcess(linker, ["-o", of, bc]).wait();
	}

private:
	/**
	 * If we are debugging print messages.
	 */
	void debugPrint(string msg, string s)
	{
		if (settings.internalDebug) {
			io.output.writefln(msg, s);
		}
	}

	void debugPasses()
	{
		if (settings.internalDebug && !mDebugPassesRun) {
			mDebugPassesRun = true;
			foreach (pass; debugVisitors) {
				foreach (mod; mCommandLineModules) {
					pass.transform(mod);
				}
			}
		}
	}

	void preDiff(ir.Module[] mods, string title, string[] ppstrs, string[] dpstrs)
	{
		if (!settings.internalDiff) {
			return;
		}

		assert(mods.length == ppstrs.length && mods.length == dpstrs.length);
		StringBuffer ppBuf, dpBuf;
		version (Volt) {
			auto diffPP = new PrettyPrinter(" ", ppBuf.sink);
			auto diffDP = new DebugPrinter(" ", dpBuf.sink);
		} else {
			auto diffPP = new PrettyPrinter(" ", &ppBuf.sink);
			auto diffDP = new DebugPrinter(" ", &dpBuf.sink);
		}
		foreach (i, m; mods) {
			ppBuf.clear();
			dpBuf.clear();
			io.output.writefln("Transformations performed by %s:", title);
			diffPP.transform(m);
			diffDP.transform(m);
			ppstrs[i] = ppBuf.str;
			dpstrs[i] = dpBuf.str;
		}
		diffPP.close();
		diffDP.close();
	}

	void postDiff(ir.Module[] mods, string[] ppstrs, string[] dpstrs)
	{
		if (!settings.internalDiff) {
			return;
		}
		assert(mods.length == ppstrs.length && mods.length == dpstrs.length);
		StringBuffer sb;
		version (Volt) {
			auto pp = new PrettyPrinter(" ", sb.sink);
			auto dp = new DebugPrinter(" ", sb.sink);
		} else {
			auto pp = new PrettyPrinter(" ", &sb.sink);
			auto dp = new DebugPrinter(" ", &sb.sink);
		}
		foreach (i, m; mods) {
			sb.clear();
			dp.transform(m);
			diff(dpstrs[i], sb.str);
			sb.clear();
			pp.transform(m);
			diff(ppstrs[i], sb.str);
		}
		pp.close();
		dp.close();
	}
}

string getOutput(Settings settings, string def)
{
	return settings.outputFile is null ? def : settings.outputFile;
}

version (Windows) {
	enum DEFAULT_BC = "a.bc";
	enum DEFAULT_OBJ = "a.obj";
	enum DEFAULT_EXE = "a.exe";
} else {
	enum DEFAULT_BC = "a.bc";
	enum DEFAULT_OBJ = "a.obj";
	enum DEFAULT_EXE = "a.out";
}
