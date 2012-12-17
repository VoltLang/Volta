// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.controller;

import core.exception;
import std.process : system;
import std.stdio : stderr;

import volt.util.path;
import volt.exceptions;
import volt.interfaces;

import volt.parser.parser;
import volt.semantic.languagepass;
import volt.llvm.backend;


/**
 * Default implementation of @link volt.interfaces.Controller Controller@endlink, replace
 * this if you wish to change the basic operation of the compiler.
 */
class VoltController : Controller
{
public:
	Settings settings;
	Frontend frontend;
	Pass languagePass;
	Backend backend;

protected:
	string mCurrentFile;
	string[] mFiles;
	ir.Module[string] mModules;

public:
	this(Settings s)
	{
		auto p = new Parser();
		p.dumpLex = false;

		auto lp = new LanguagePass(s, this);

		auto b = new LlvmBackend(s.outputFile is null);

		this(s, p, lp, b);
	}

	/**
	 * Retrieve a Module by its name. Returns null if none is found.
	 */
	ir.Module getModule(ir.QualifiedName name)
	{
		auto p = name.toString() in mModules;
		if (p is null) {
			return null;
		}
		return *p;
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
		mFiles ~= file;
	}

	void addFiles(string[] files...)
	{
		this.mFiles ~= files;
	}

	int compile()
	{
		int ret;
		try {
			ret = intCompile();
		} catch (CompilerPanic e) {
			stderr.writefln(e.msg);
			if (e.file !is null)
				stderr.writefln("%s:%s", e.file, e.line);
			return 2;
		} catch (CompilerError e) {
			stderr.writefln(e.msg);
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
	int intCompile()
	{
		foreach (file; mFiles) {
			mCurrentFile = file;

			Location loc;
			loc.filename = file;
			auto src = cast(string) read(loc.filename);
			auto m = frontend.parseNewFile(src, loc);
			mModules[m.name.toString()] = m;
		}

		string linkInputFiles;
		foreach (name, _module; mModules) {

			languagePass.transform(_module);

			if (settings.noBackend)
				continue;

			// this is just during bring up.
			string o = temporaryFilename(".bc");
			backend.setTarget(o, TargetType.LlvmBitcode);
			backend.compile(_module);
			linkInputFiles ~= " \"" ~ o ~ "\" ";
		}

		if (settings.noBackend)
			return 0;

		string of = settings.outputFile is null ? DEFAULT_EXE : settings.outputFile;
		string cmd;
		int ret;

		if (settings.noLink) {
			string link = temporaryFilename(".bc");
			cmd = format("llvm-link -o \"%s\" %s", link, linkInputFiles);
			ret = system(cmd);
			if (ret)
				return ret;

			string as = temporaryFilename("*.as");
			cmd = format("llc -o \"%s\" \"%s\"", as, link);
			ret = system(cmd);
			if (ret)
				return ret;

			cmd = format("llvm-mc -filetype=obj -o \"%s\" \"%s\"", of, as);
			ret = system(cmd);
			if (ret)
				return ret;
		} else {
			cmd = format("llvm-ld -native -o \"%s\" %s", of, linkInputFiles);
			ret = system(cmd);
			if (ret)
				return ret;
		}

		return 0;
	}

	this(Settings s, Frontend f, Pass lp, Backend b)
	{
		this.settings = s;
		this.frontend = f;
		this.languagePass = lp;
		this.backend = b;
	}
}

version (Windows) {
	enum DEFAULT_EXE = "a.exe";
} else {
	enum DEFAULT_EXE = "a.out";
}
