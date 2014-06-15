// Copyright © 2012-2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.controller;

import core.exception;
import std.algorithm : endsWith;
import std.path : dirSeparator;
import std.file : remove, exists;
import std.process : system;
import std.stdio : stderr, stdout;

import volt.util.path;
import volt.exceptions;
import volt.interfaces;
import volt.errors;

import volt.parser.parser;
import volt.semantic.languagepass;
import volt.llvm.backend;
import volt.util.mangledecoder;

import volt.visitor.prettyprinter;
import volt.visitor.debugprinter;
import volt.visitor.docprinter;
import volt.visitor.jsonprinter;


/**
 * Default implementation of @link volt.interfaces.Controller Controller@endlink, replace
 * this if you wish to change the basic operation of the compiler.
 */
class VoltController : Controller
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
	ir.Module[string] mModulesByName;
	ir.Module[string] mModulesByFile;

	string[] mLibraryFiles;
	string[] mLibraryPaths;

	string[] mFrameworkNames;
	string[] mFrameworkPaths;

public:
	this(Settings s)
	{
		this.settings = s;

		auto p = new Parser();
		p.dumpLex = false;

		auto lp = new VoltLanguagePass(s, p, this);

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
	ir.Module getModule(ir.QualifiedName name)
	{
		auto p = name.toString() in mModulesByName;
		ir.Module m;

		if (p !is null)
			m = *p;

		string[] validPaths;
		foreach (path; mIncludes) {
			if (m !is null)
				break;

			auto paths = genPossibleFilenames(path, name.strings);

			foreach (possiblePath; paths) {
				if (exists(possiblePath)) {
					validPaths ~= possiblePath;
				}
			}
		}

		if (m is null) {
			if (validPaths.length == 0) {
				return null;
			}
			if (validPaths.length > 1) {
				throw makeMultipleValidModules(name, validPaths);
			}
			m = loadAndParse(validPaths[0]);
		}

		// Need to make sure that this module can
		// be used by other modules.
		if (m !is null) {
			languagePass.phase1(m);
		}

		return m;
	}

	void close()
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

		if (file in mModulesByFile) {
			return mModulesByFile[file];
		}

		auto src = cast(string) read(loc.filename);
		auto m = frontend.parseNewFile(src, loc);
		if (m.name.toString() in mModulesByName) {
			throw makeAlreadyLoaded(m, file);
		}

		mModulesByFile[file] = m;
		mModulesByName[m.name.toString()] = m;

		return m;
	}

	int intCompile()
	{
		ir.Module[] mods;

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
					foreach(mod; mods) {
						pass.transform(mod);
					}
				}
			}
		}
		scope(failure) debugPasses();

		// Load all modules to be compiled.
		// Don't run phase 1 on them yet.
		auto dp = new DocPrinter(languagePass);
		auto jp = new JsonPrinter(languagePass);
		foreach (file; mSourceFiles) {
			debugPrint("Parsing %s.", file);
			mods ~= loadAndParse(file);
			if (settings.writeDocs) {
				dp.transform(mods[$-1]);
			}
		}
		if (settings.writeJson) {
			jp.transform(mods);
		}

		// After we have loaded all of the modules
		// setup the pointers, this allows for suppling
		// a user defined object module.
		auto lp = cast(VoltLanguagePass)languagePass;
		lp.setupOneTruePointers();

		// Force phase 1 to be executed on the modules.
		foreach (mod; mods)
			languagePass.phase1(mod);

		ir.Module[] dmdIsStupid;
		foreach (mod; mModulesByName)
			dmdIsStupid ~= mod;

		// All modules need to be run trough phase2.
		languagePass.phase2(dmdIsStupid);

		// All modules need to be run trough phase3.
		languagePass.phase3(dmdIsStupid);

		debugPasses();

		if (settings.noBackend)
			return 0;

		// We will be modifing this later on,
		// but we don't want to change mBitcodeFiles.
		string[] bitcodeFiles = mBitcodeFiles;
		string[] temporaryFiles;

		foreach (mod; mods) {
			string o = temporaryFilename(".bc");
			backend.setTarget(o, TargetType.LlvmBitcode);
			debugPrint("Backend %s.", mod.name.toString());
			backend.compile(mod);
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
			linkModules(bc, bitcodeFiles);
		}

		// When outputting bitcode we are now done.
		if (settings.emitBitcode) {
			return 0;
		}

		// If we are compiling on the emscripten platform ignore .o files.
		if (settings.platform == Platform.EMSCRIPTEN) {
			return emscriptenLink(mLinker, bc, of);
		}

		// Native compilation, turn the bitcode into native code.
		writeObjectFile(settings, obj, bc);

		// When not linking we are now done.
		if (settings.noLink) {
			return 0;
		}

		// And finally call the linker.
		ret = nativeLink(mLinker, obj, of);
		if (ret)
			return 0;

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

		return system(cmd);
	}

	int emscriptenLink(string linker, string bc, string of)
	{
		string cmd = format("%s -o \"%s\" %s", linker, of, bc);
		return system(cmd);
	}

	this(Settings s, Frontend f, LanguagePass lp, Backend b)
	{
		this.settings = s;
		this.frontend = f;
		this.languagePass = lp;
		this.backend = b;
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
