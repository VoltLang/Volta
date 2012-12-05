// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module main;

import std.stdio : readln;
import std.path : exists;
import std.file : read;
import std.random : uniform;
import std.process : getenv, system;

import volt.license;
import volt.interfaces;

import volt.token.stream;
import volt.token.source;
import volt.token.lexer;
import volt.token.location;

import volt.parser.parser;

import volt.visitor.print;
import volt.visitor.debugprint;

import volt.semantic.attribremoval;
import volt.semantic.context;
import volt.semantic.condremoval;
import volt.semantic.declgatherer;
import volt.semantic.userresolver;
import volt.semantic.typeverifier;
import volt.semantic.exptyper;
import volt.semantic.refrep;
import volt.semantic.arraylowerer;
import volt.semantic.manglewriter;

import volt.llvm.backend;

version (Windows) {
	enum DEFAULT_EXE = "a.exe";
} else {
	enum DEFAULT_EXE = "a.out";
}

int main(string[] args)
{
	// Arguments setup.
	auto settings = new Settings();

	if (!filterArgs(args, settings))
		return 0;

	if (args.length <= 1) {
		writefln("%s: no input files", args[0]);
		return 0;
	}

	if (args.length > 2) {
		/// @todo fix this.
		writefln("%s, to many input files", args[0]);
		return 1;
	}


	// Setup the compiler.
	Pass[] passes;
	passes ~= new AttribRemoval();
	passes ~= new ConditionalRemoval(settings);
	passes ~= new ContextBuilder();
	passes ~= new UserResolver();
	passes ~= new DeclarationGatherer();
	passes ~= new TypeDefinitionVerifier();
	passes ~= new ExpTyper(settings);
	passes ~= new ReferenceReplacer();
	passes ~= new ArrayLowerer(settings);
	passes ~= new MangleWriter();

	if (!settings.noBackend && settings.outputFile is null) {
		passes ~= new DebugPrintVisitor("Running DebugPrintVisitor:");
		passes ~= new PrintVisitor("Running PrintVisitor:");
	}

	auto p = new Parser();
	p.dumpLex = false;

	// Compile all files.
	foreach(arg; args[1 .. $]) {
		Location loc;
		loc.filename = arg;
		auto src = cast(string)read(loc.filename);
		auto m = p.parseNewFile(src, loc);

		foreach(pass; passes)
			pass.transform(m);

		auto b = new LlvmBackend(settings.outputFile is null);

		// this is just during bring up.
		string o = settings.outputFile is null ? "output.bc" : temporaryFilename(".bc");
		b.setTarget(o, TargetType.LlvmBitcode);
		b.compile(m);
		b.close();

		string of = settings.outputFile is null ? DEFAULT_EXE : settings.outputFile;
		system(format("llvm-ld -native -o \"%s\" \"%s\"", of, o));
	}

	return 0;
}

bool filterArgs(ref string[] args, Settings settings)
{
	void delegate(string) argHandler;
	string[] ret;
	int i;
	ret.length = args.length;

	// Handlers.
	void outputFile(string file) {
		settings.outputFile = file;
	}

	// Skip the first argument.
	ret[i++] = args[0];

	foreach(arg; args[1 .. $])  {
		if (argHandler !is null) {
			argHandler(arg);
			argHandler = null;
			continue;
		}

		switch (arg) {
		case "-license", "--license":
			return printLicense();
		case "-o":
			argHandler = &outputFile;
			continue;
		case "-w":
			settings.warningsEnabled = true;
			continue;
		case "-d":
			settings.debugEnabled = true;
			continue;
		case "--no-backend":
		case "-S":
			settings.noBackend = true;
			continue;
		default:
		}

		ret[i++] = arg;
	}

	ret.length = i;
	args = ret;
	return true;
}

bool printLicense()
{
	foreach(license; licenseArray)
		writefln(license);
	return false;
}

/**
 * Generate a filename in a temporary directory that doesn't exist.
 *
 * Params:
 *   extension = a string to be appended to the filename. Defaults to an empty string.
 *
 * Returns: an absolute path to a unique (as far as we can tell) filename. 
 */
string temporaryFilename(string extension = "")
{
	version (Windows) {
		string prefix = getenv("TEMP") ~ '/';
	} else {
		string prefix = "/tmp/";
	}

	string filename;
	do {
		filename = randomString(32);
		filename = prefix ~ filename ~ extension;
	} while (exists(filename));

	return filename;
}

/**
 * Generate a random string `length` characters long.
 */
string randomString(size_t length)
{
	auto str = new char[length];
	foreach (i; 0 .. length) {
		char c;
		switch (uniform(0, 3)) {
		case 0:
			c = uniform!("[]", char, char)('0', '9');
			break;
		case 1:
			c = uniform!("[]", char, char)('a', 'z');
			break;
		case 2:
			c = uniform!("[]", char, char)('A', 'Z');
			break;
		default:
			assert(false);
		}
		str[i] = c;
	}
	return str.idup;    
}
