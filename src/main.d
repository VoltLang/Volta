// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module main;

import std.stdio : File, writefln;

import volt.license;
import volt.interfaces;
import volt.controller;


int main(string[] args)
{
	string[] files;
	auto cmd = args[0];
	args = args[1 .. $];

	auto settings = new Settings();
	setDefault(settings);

	if (!handleArgs(args, files, settings))
		return 0;

	settings.setVersionsFromOptions();

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
		case "-license", "--license":
			return printLicense();
		case "-o":
			argHandler = &outputFile;
			continue;
		case "-I":
			argHandler = &includePath;
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
		case "--no-stdlib":
			settings.noStdLib = true;
			continue;
		case "--internal-dbg":
			settings.internalDebug = true;
			continue;
		case "--help", "-h":
			return printUsage();
		default:
		}

		files ~= arg;
	}

	return true;
}

bool getLinesFromFile(string file, ref string[] lines)
{
	try {
		auto f = File(file);
		foreach(line; f.byLine) {
			if (line.length > 0 && line[0] != '#') {
				lines ~= line.idup;
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
	writefln("\t--license       Print license information and quit.");
	writefln("\t-o outputname   Set output to outputname.");
	writefln("\t-I path         Add a include path.");
	writefln("\t-w              Enable warnings.");
	writefln("\t-d              Compile in debug mode.");
	writefln("\t-c              Compile only, do not link.");
	writefln("\t--emit-bitcode  Emit LLVM bitcode (implies -c).");
	writefln("\t-S,--no-backend Stop compilation before the backend.");
	writefln("\t--no-catch      For compiler debugging purposes.");
	writefln("\t--internal-dbg  Enables internal debug printing.");
	writefln("\t-h,--help       Print this message and quit.");
	return false;
}

bool printLicense()
{
	foreach(license; licenseArray)
		writefln(license);
	return false;
}

