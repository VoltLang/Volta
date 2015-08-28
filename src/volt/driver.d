// Copyright © 2012-2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.driver;

import core.exception;
import std.algorithm : endsWith;
import std.path : dirSeparator;
import std.file : remove, exists, read;
import std.process : wait, spawnShell;
import std.stdio : stderr, stdout;

import watt.text.diff;
import watt.path : temporaryFilename;

import volt.util.path;
import volt.util.perf : perf;
import volt.exceptions;
import volt.interfaces;
import volt.errors;

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
	Settings settings;
	Frontend frontend;
	LanguagePass languagePass;
	Backend backend;

	Pass[] debugVisitors;

protected:
	string mLinker;

	string[] mIncludes;
	string[] mSourceFiles;
	string[] mBitcodeFiles;
	string[] mObjectFiles;

	string[] mLibraryFiles;
	string[] mLibraryPaths;

	string[] mFrameworkNames;
	string[] mFrameworkPaths;

	ir.Module[] mCommandLineModules;

public:
	this(Settings s)
	{
		this.settings = s;

		auto p = new Parser();
		p.dumpLex = false;

		auto lp = new VoltLanguagePass(this, s, p);

		auto b = new LlvmBackend(lp);

		this(s, p, lp, b);

		mIncludes = settings.includePaths;

		mLibraryPaths = settings.libraryPaths;
		mLibraryFiles = settings.libraryFiles;

		mFrameworkNames = settings.frameworkNames;
		mFrameworkPaths = settings.frameworkPaths;

		// Add the stdlib includes and files.
		if (!settings.noStdLib) {
			mIncludes = settings.stdIncludePaths ~ mIncludes;
		}

		// Should we add the standard library.
		if (!settings.emitBitcode &&
		    !settings.noLink &&
		    !settings.noStdLib) {
			foreach (file; settings.stdFiles) {
				addFile(file);
			}
		}

		if (settings.linker is null) {
			if (settings.platform == Platform.EMSCRIPTEN) {
				mLinker = "emcc";
			} else {
				mLinker = "gcc";
			}
		} else {
			mLinker = settings.linker;
		}

		debugVisitors ~= new DebugMarker("Running DebugPrinter:");
		debugVisitors ~= new DebugPrinter();
		debugVisitors ~= new DebugMarker("Running PrettyPrinter:");
		debugVisitors ~= new PrettyPrinter();
	}

	/**
	 * Retrieve a Module by its name. Returns null if none is found.
	 */
	override ir.Module loadModule(ir.QualifiedName name)
	{
		string[] validPaths;
		foreach (path; mIncludes) {
			auto paths = genPossibleFilenames(path, name.strings);

			foreach (possiblePath; paths) {
				if (exists(possiblePath)) {
					validPaths ~= possiblePath;
				}
			}
		}

		if (validPaths.length == 0) {
			return null;
		}
		if (validPaths.length > 1) {
			throw makeMultipleValidModules(name, validPaths);
		}

		return loadAndParse(validPaths[0]);
	}

	override ir.Module[] getCommandLineModules()
	{
		return mCommandLineModules;
	}

	override void close()
	{
		frontend.close();
		languagePass.close();
		backend.close();

		settings = null;
		frontend = null;
		languagePass = null;
		backend = null;
	}

	void addFile(string file)
	{
		file = settings.replaceEscapes(file);
		version (Windows) {
			file = toLower(file);  // VOLT TEST.VOLT  REM Reppin' MS-DOS
		}

		if (endsWith(file, ".d", ".volt") > 0) {
			mSourceFiles ~= file;
		} else if (endsWith(file, ".bc")) {
			mBitcodeFiles ~= file;
		} else if (endsWith(file, ".o", ".obj")) {
			mObjectFiles ~= file;
		} else {
			auto str = format("unknown file type %s", file);
			throw new CompilerError(str);
		}
	}

	void addFiles(string[] files)
	{
		foreach(file; files)
			addFile(file);
	}

	void addLibrary(string lib)
	{
		mLibraryFiles ~= lib;
	}

	void addLibraryPath(string path)
	{
		mLibraryPaths ~= path;
	}

	void addLibrarys(string[] libs)
	{
		foreach(lib; libs)
			addLibrary(lib);
	}

	void addLibraryPaths(string[] paths)
	{
		foreach(path; paths)
			addLibraryPath(path);
	}

	int compile()
	{
		int ret;
		if (settings.noCatch) {
			ret = intCompile();
		} else try {
			ret = intCompile();
		} catch (CompilerPanic e) {
			stderr.writefln(e.msg);
			if (e.file !is null)
				stderr.writefln("%s:%s", e.file, e.line);
			return 2;
		} catch (CompilerError e) {
			stderr.writefln(e.msg);
			debug if (e.file !is null)
				stderr.writefln("%s:%s", e.file, e.line);
			return 1;
		} catch (Exception e) {
			stderr.writefln("panic: %s", e.msg);
			if (e.file !is null)
				stderr.writefln("%s:%s", e.file, e.line);
			return 2;
		} catch (Error e) {
			stderr.writefln("panic: %s", e.msg);
			if (e.file !is null)
				stderr.writefln("%s:%s", e.file, e.line);
			return 2;
		}

		return ret;
	}

protected:
	/**
	 * Loads a file and parses it, also adds it to the loaded modules.
	 */
	ir.Module loadAndParse(string file)
	{
		Location loc;
		loc.filename = file;

		auto src = cast(string) read(loc.filename);
		return frontend.parseNewFile(src, loc);
	}

	int intCompile()
	{
		scope(exit) {
			perf.tag("exit");
		}

		void debugPrint(string msg, string s)
		{
			if (settings.internalDebug) {
				stdout.writefln(msg, s);
			}
		}

		bool debugPassesRun = false;
		void debugPasses()
		{
			if (settings.internalDebug && !debugPassesRun) {
				debugPassesRun = true;
				foreach(pass; debugVisitors) {
					foreach(mod; mCommandLineModules) {
						pass.transform(mod);
					}
				}
			}
		}
		scope(failure) debugPasses();

		perf.tag("parsing");

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

		// After we have loaded all of the modules
		// setup the pointers, this allows for suppling
		// a user defined object module.
		auto lp = cast(VoltLanguagePass)languagePass;
		lp.setupOneTruePointers();

		// Setup diff buffers.
		auto ppstrs = new string[](mCommandLineModules.length);
		auto dpstrs = new string[](mCommandLineModules.length);

		preDiff(mCommandLineModules, "Phase 1", ppstrs, dpstrs);
		perf.tag("phase1");

		// Force phase 1 to be executed on the modules.
		// This might load new modules.
		languagePass.phase1(mCommandLineModules);
		postDiff(mCommandLineModules, ppstrs, dpstrs);

		// We are done now.
		if (settings.removeConditionalsOnly) {
			return 0;
		}

		// New modules have been loaded,
		// make sure to run everthing on them.
		auto allMods = languagePass.getModules();

		preDiff(mCommandLineModules, "Phase 2", ppstrs, dpstrs);
		perf.tag("phase2");

		// All modules need to be run through phase2.
		languagePass.phase2(allMods);
		postDiff(mCommandLineModules, ppstrs, dpstrs);

		preDiff(mCommandLineModules, "Phase 3", ppstrs, dpstrs);
		perf.tag("phase3");

		// All modules need to be run through phase3.
		languagePass.phase3(allMods);
		postDiff(mCommandLineModules, ppstrs, dpstrs);

		debugPasses();

		perf.tag("backend");
		if (settings.noBackend) {
			return 0;
		}

		// We will be modifing this later on,
		// but we don't want to change mBitcodeFiles.
		string[] bitcodeFiles = mBitcodeFiles;
		string[] temporaryFiles;

		foreach (m; mCommandLineModules) {
			string o = temporaryFilename(".bc");
			backend.setTarget(o, TargetType.LlvmBitcode);
			debugPrint("Backend %s.", m.name.toString());
			backend.compile(m);
			bitcodeFiles ~= o;
			temporaryFiles ~= o;
		}

		string bc, obj, of;

		scope(exit) {
			foreach (f; temporaryFiles)
				f.remove();
			
			if (bc.exists() && !settings.emitBitcode)
				bc.remove();

			if (obj.exists() && !settings.noLink)
				obj.remove();
		}

		int ret;

		if (settings.emitBitcode) {
			bc = settings.getOutput(DEFAULT_BC);
		} else {
			if (bitcodeFiles.length == 1) {
				bc = bitcodeFiles[0];
				bitcodeFiles = null;
			} else {
				bc = temporaryFilename(".bc");
			}
		}

		if (settings.noLink) {
			obj = settings.getOutput(DEFAULT_OBJ);
		} else {
			of = settings.getOutput(DEFAULT_EXE);
			obj = temporaryFilename(".o");
		}

		// Link bitcode files
		if (bitcodeFiles.length > 0) {
			perf.tag("bitcode-link");
			linkModules(bc, bitcodeFiles);
		}

		// When outputting bitcode we are now done.
		if (settings.emitBitcode) {
			return 0;
		}

		// If we are compiling on the emscripten platform ignore .o files.
		if (settings.platform == Platform.EMSCRIPTEN) {
			perf.tag("emscripten-link");
			return emscriptenLink(mLinker, bc, of);
		}


		// Native compilation, turn the bitcode into native code.
		perf.tag("object");
		writeObjectFile(settings, obj, bc);

		// When not linking we are now done.
		if (settings.noLink) {
			return 0;
		}

		// And finally call the linker.
		perf.tag("native-link");
		ret = nativeLink(mLinker, obj, of);
		// TODO we probably did this for a reason, find out why.
		return 0;
	}

	int nativeLink(string linker, string obj, string of)
	{
		string objInputFiles;
		foreach (objectFile; mObjectFiles) {
			objInputFiles ~= objectFile ~ " ";
		}
		string objLibraryPaths;
		foreach (libraryPath; mLibraryPaths) {
			objLibraryPaths ~= " -L" ~ libraryPath;
		}
		string objLibraryFiles;
		foreach (libraryFile; mLibraryFiles) {
			objLibraryFiles ~= " -l" ~ libraryFile;
		}
		string objFrameworkPaths;
		foreach (frameworkPath; mFrameworkPaths) {
			objLibraryPaths ~= " -F " ~ frameworkPath;
		}
		string objFrameworkNames;
		foreach (frameworkName; mFrameworkNames) {
			objFrameworkNames ~= " -framework " ~ frameworkName;
		}

		objInputFiles ~= " " ~ obj;

		string cmd = format("%s -o \"%s\" %s%s%s%s%s", linker, of,
		                    objInputFiles, objLibraryPaths, objLibraryFiles,
		                    objFrameworkPaths, objFrameworkNames);

		return wait(spawnShell(cmd));
	}

	int emscriptenLink(string linker, string bc, string of)
	{
		string cmd = format("%s -o \"%s\" %s", linker, of, bc);
		return wait(spawnShell(cmd));
	}

	this(Settings s, Frontend f, LanguagePass lp, Backend b)
	{
		this.settings = s;
		this.frontend = f;
		this.languagePass = lp;
		this.backend = b;
	}

	private void preDiff(ir.Module[] mods, string title, string[] ppstrs, string[] dpstrs)
	{
		if (!settings.internalDiff) {
			return;
		}
		assert(mods.length == ppstrs.length && mods.length == dpstrs.length);
		StringBuffer ppBuf, dpBuf;
		auto diffPP = new PrettyPrinter(" ", &ppBuf.sink);
		auto diffDP = new DebugPrinter(" ", &dpBuf.sink);
		foreach (i, m; mods) {
			ppBuf.clear();
			dpBuf.clear();
			stdout.writefln("Transformations performed by %s:", title);
			diffPP.transform(m);
			diffDP.transform(m);
			ppstrs[i] = ppBuf.str;
			dpstrs[i] = dpBuf.str;
		}
		diffPP.close();
		diffDP.close();
	}

	private void postDiff(ir.Module[] mods, string[] ppstrs, string[] dpstrs)
	{
		if (!settings.internalDiff) {
			return;
		}
		assert(mods.length == ppstrs.length && mods.length == dpstrs.length);
		StringBuffer sb;
		auto pp = new PrettyPrinter(" ", &sb.sink);
		auto dp = new DebugPrinter(" ", &sb.sink);
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
