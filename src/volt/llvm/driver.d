/*#D*/
// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.driver;

import watt.io.file : remove, exists, isFile, getcwd;
import watt.text.format : format;
import watt.process : spawnProcess, wait;

import volt.util.path : TempfileManager;
import volt.util.perf : Perf, perf;
import volt.util.cmdgroup : CmdGroup;

import ir = volta.ir;

import volt.exceptions;
import volt.interfaces;

import volt.llvm.backend;


/*!
 * Settings for @ref volt.llvm.driver.LLVMDriver.
 */
class LLVMDriverSettings
{
	string ar;
	string clang;
	string linker;

	string[] libFiles;
	string[] libraryPaths;
	string[] libraryFlags;
	string[] frameworkPaths;
	string[] frameworkNames;

	string[] xCC;
	string[] xLD;
	string[] xLink;
	string[] xClang;
	string[] xLinker;

	bool linkWithCC;
	bool linkWithLink;
}

/*!
 * The beckend part of the @ref volt.interfaces.Driver that handles the backend
 * and running of the commands.
 *
 * @ingroup backend llvmbackend
 */
class LLVMDriver
{
public:
	Driver d;
	LanguagePass lp;
	TempfileManager tempMan;
	TargetInfo target;
	Backend backend;
	LLVMDriverSettings ls;


private:
	int mClangReturn;


public:
	this(Driver d, TempfileManager tm, TargetInfo target, LanguagePass lp,
	     Backend backend, LLVMDriverSettings ls)
	{
		this.d = d;
		this.tempMan = tm;
		this.target = target;
		this.lp = lp;
		this.backend = backend;
		this.ls = ls;
	}


	/*
	 *
	 * Main entry points.
	 *
	 */

	/*!
	 * Make a single bitcode files out of all given
	 * modules and bitcode files.
	 */
	int makeBitcode(string of, ir.Module[] mods, string[] bitcodeFiles)
	{
		// Create backend results that are later written out to files.
		perf.mark(Perf.Mark.BACKEND);
		auto results = turnModulesIntoResults(
			mods, TargetType.LlvmBitcode);

		// Count writing out files as assembling.
		perf.mark(Perf.Mark.ASSEMBLE);
		bitcodeFiles ~= turnResultsIntoFiles(results, ".bc");

		// Link all of the bitcode files into one module.
		perf.mark(Perf.Mark.BITCODE);
		linkModules(of, bitcodeFiles);

		return 0;
	}

	/*!
	 * Make a single object files out of all given
	 * modules and bitcode files.
	 */
	int makeObject(string of, ir.Module[] mods, string[] bitcodeFiles)
	{
		// Reuse the above function, it does time tracking.
		auto bc = tempMan.getTempFile(".bc");
		if (auto ret = makeBitcode(bc, mods, bitcodeFiles)) {
			return ret;
		}

		// Native compilation, turn the bitcode into native code.
		perf.mark(Perf.Mark.ASSEMBLE);
		writeObjectFile(target, of, bc);

		// Throws on failure.
		return 0;
	}

	/*!
	 * Make a single ar archive out of all given modules,
	 * bitcode files and object files.
	 */
	int makeArchive(string of, ir.Module[] mods, string[] bitcodeFiles, string[] objectFiles)
	{
		// Create backend results that are later written out to files.
		perf.mark(Perf.Mark.BACKEND);
		auto results = turnModulesIntoResults(
			mods, TargetType.LlvmBitcode);

		// Assemble files into object files for linking.
		perf.mark(Perf.Mark.ASSEMBLE);
		objectFiles ~= runClang(ls, results, bitcodeFiles);

		// Finally do the link
		perf.mark(Perf.Mark.LINK);
		return runAr(ls.ar, of, objectFiles);
	}

	/*!
	 * Run the native linker.
	 */
	int doNativeLink(string of, ir.Module[] mods, string[] bitcodeFiles, string[] objectFiles)
	{
		// Reuse the above function, it does time tracking.
		auto o = tempMan.getTempFile(".o");
		if (auto ret = makeObject(o, mods, bitcodeFiles)) {
			return ret;
		}

		// Add the final big object file to objects to link.
		objectFiles ~= o;

		// Finally do the link
		perf.mark(Perf.Mark.LINK);
		if (ls.linkWithLink) {
			return runLink(ls, of, objectFiles);
		} else if (ls.linkWithCC) {
			return runCC(ls, of, objectFiles);
		} else {
			assert(false);
		}
	}


	/*
	 *
	 * Helper producer functions.
	 *
	 */

protected:
	BackendFileResult[] turnModulesIntoResults(ir.Module[] mods, TargetType targetType)
	{
		// Nothing to do.
		if (mods.length == 0) {
			return null;
		}

		BackendFileResult[] ret = new BackendFileResult[](mods.length);

		auto ehPersonalityFunc = lp.ehPersonalityFunc;
		auto llvmTypeidFor = lp.llvmTypeidFor;
		auto execDir = d.execDir;
		auto identStr = d.identStr;

		// Generate bc files for the compiled modules.
		foreach (i, m; mods) {
			ret[i] = backend.compileFile(m, targetType,
				ehPersonalityFunc, llvmTypeidFor,
				execDir, getcwd(), identStr);
		}

		return ret;
	}

	string[] turnBitcodeIntoObject(string[] bitcodeFiles)
	{
		// Nothing to do.
		if (bitcodeFiles.length == 0) {
			return null;
		}

		auto ret = new string[](bitcodeFiles.length);

		// Native compilation, turn the bitcode into native code.
		foreach (i, bc; bitcodeFiles) {
			string obj = tempMan.getTempFile(".o");
			writeObjectFile(target, obj, bc);
			ret[i] = obj;
		}

		return ret;
	}

	string[] turnResultsIntoFiles(BackendFileResult[] results, string ending)
	{
		// Nothing to do.
		if (results.length == 0) {
			return null;
		}

		string[] ret = new string[](results.length);

		// Generate bc files for the compiled modules.
		foreach (i, result; results) {
			string file = tempMan.getTempFile(ending);

			result.saveToFile(file);
			result.close();
			ret[i] = file;
		}

		return ret;
	}

	string[] turnBitcodesIntoObjects(string[] bitcodeFiles)
	{
		// Nothing to do.
		if (bitcodeFiles.length == 0) {
			return null;
		}

		string[] ret = new string[](bitcodeFiles.length);

		foreach (i, bc; bitcodeFiles) {
			string obj = tempMan.getTempFile(".o");
			writeObjectFile(target, obj, bc);
			ret[i] = obj;
		}

		return ret;
	}

	string[] runClang(LLVMDriverSettings ls, BackendFileResult[] results, string[] bitcodeFiles)
	{
		// Nothing to do.
		if (bitcodeFiles.length == 0 && results.length == 0) {
			return null;
		}

		// Turn the results into bitcode files that clang can load.
		bitcodeFiles ~= turnResultsIntoFiles(results, ".bc");

		auto clangArgs = getClangArgs(ls);
		auto cmd = new CmdGroup(8);
		auto ret = new string[](bitcodeFiles.length);
		foreach (i, bc; bitcodeFiles) {
			// Abort the loop if a command has failed.
			if (mClangReturn != 0) {
				break;
			}

			string obj = tempMan.getTempFile(".o");
			auto args = clangArgs ~ ["-c", "-o", obj, bc];
			cmd.run(ls.clang, args, checkClangReturn);

			ret[i] = obj;
		}

		cmd.waitAll();

		if (mClangReturn) {
			auto msg = format("clang sub-command failed '%s'", mClangReturn);
			throw new CompilerError(msg);
		}

		return ret;
	}

	int runAr(string ar, string of, string[] objectFiles)
	{
		auto arArgs = ["rcv", of] ~ objectFiles;

		// If the file exists remove it.
		if (of.exists() && of.isFile()) {
			of.remove();
		}

		return spawnProcess(ar, arArgs).wait();
	}

	int runCC(LLVMDriverSettings ls, string of, string[] objectFiles)
	{
		string[] args = ["-o", of];

		final switch (target.arch) with (Arch) {
		case X86: args ~= "-m32"; break;
		case X86_64: args ~= "-m64"; break;
		}

		foreach (objectFile; objectFiles) {
			args ~= objectFile;
		}
		foreach (libFile; ls.libFiles) {
			args ~= libFile;
		}
		foreach (libraryPath; ls.libraryPaths) {
			args ~= format("-L%s", libraryPath);
		}
		foreach (libraryFile; ls.libraryFlags) {
			args ~= format("-l%s", libraryFile);
		}
		foreach (frameworkPath; ls.frameworkPaths) {
			args ~= "-F";
			args ~= frameworkPath;
		}
		foreach (frameworkName; ls.frameworkNames) {
			args ~= "-framework";
			args ~= frameworkName;
		}
		foreach (xCC; ls.xCC) {
			args ~= xCC;
		}
		foreach (xLD; ls.xLD) {
			args ~= "-Xlinker";
			args ~= xLD;
		}
		foreach (xLinker; ls.xLinker) {
			args ~= "-Xlinker";
			args ~= xLinker;
		}

		return spawnProcess(ls.linker, args).wait();
	}

	int runLink(LLVMDriverSettings ls, string of, string[] objectFiles)
	{
		string[] args = [
			"/MACHINE:x64",
			"/defaultlib:libcmt",
			"/defaultlib:oldnames",
			"legacy_stdio_definitions.lib",
			"/nologo",
			format("/out:%s", of)];

		foreach (objectFile; objectFiles) {
			args ~= objectFile;
		}
		foreach (libFile; ls.libFiles) {
			args ~= libFile;
		}
		// The -L argument.
		foreach (libraryPath; ls.libraryPaths) {
			args ~= format("/LIBPATH:%s", libraryPath);
		}
		// The -l argument.
		foreach (libraryFlag; ls.libraryFlags) {
			args ~= libraryFlag;
		}
		foreach (xLink; ls.xLink) {
			args ~= xLink;
		}

		// We are using msvc link directly so this is
		// linker arguments.
		foreach (xLinker; ls.xLinker) {
			args ~= xLinker;
		}

		return spawnProcess(ls.linker, args).wait();
	}


	/*
	 *
	 * Clang helper functions.
	 *
	 */

	string[] getClangArgs(LLVMDriverSettings ls)
	{
		auto clangArgs = ["-target", getTriple(target)];

		// Add command line args.
		clangArgs ~= ls.xClang;

		// Force -fPIC on linux.
		if (target.arch == Arch.X86_64 &&
		    target.platform == Platform.Linux) {
			clangArgs ~= "-fPIC";
		}

		// Clang likes to change the module target triple.
		// @TODO make battery pipe in the real triple.
		if (target.arch == Arch.X86_64 &&
		    target.platform == Platform.MSVC) {
			clangArgs ~= "-Wno-override-module";
		}

		return clangArgs;
	}

	void checkClangReturn(int result)
	{
		if (result != 0) {
			mClangReturn = result;
		}
	}

	version (D_Version2) CmdGroup.DoneDg checkClangReturn()
	{
		return &checkClangReturn;
	}
}
