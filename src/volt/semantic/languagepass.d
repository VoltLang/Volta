module volt.semantic.languagepass;

import std.file : read, exists;
import std.random : uniform;
import std.process : getenv, system;

import ir = volt.ir.ir;

import volt.interfaces;

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

class LanguagePass
{
public:
	Pass[] passes;
	Settings settings;
	Backend backend;
	string[] files;

public:
	void addFile(string file)
	{
		files ~= file;
	}

	void addFiles(string[] files...)
	{
		this.files ~= files;
	}

	void compile()
	{
		auto p = new Parser();
		p.dumpLex = false;

		foreach(arg; files) {
			Location loc;
			loc.filename = arg;
			auto src = cast(string)read(loc.filename);
			auto m = p.parseNewFile(src, loc);

			foreach(pass; passes)
				pass.transform(m);

			// this is just during bring up.
			string o = settings.outputFile is null ? "output.bc" : temporaryFilename(".bc");
			backend.setTarget(o, TargetType.LlvmBitcode);
			backend.compile(m);
			backend.close();

			/// @todo Whoaaah, this shouldn't be here.
			string of = settings.outputFile is null ? DEFAULT_EXE : settings.outputFile;
			system(format("llvm-ld -native -o \"%s\" \"%s\"", of, o));
		}
	}

public:
	this(Settings settings, Backend backend)
	{
		this.settings = settings;
		this.backend = backend;

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
	}
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
