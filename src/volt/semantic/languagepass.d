module volt.semantic.languagepass;

import std.file : read;
import std.process : getenv, system;

import ir = volt.ir.ir;

import volt.util.path;

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

private:
	ir.Module[string] mModules;

public:
	/// Retrieve a Module by its name. Returns null if none is found.
	ir.Module getModule(ir.QualifiedName name)
	{
		auto p = name.toString() in mModules;
		if (p is null) {
			return null;
		}
		return *p;
	}

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

		foreach (file; files) {
			Location loc;
			loc.filename = file;
			auto src = cast(string) read(loc.filename);
			auto m = p.parseNewFile(src, loc);
			mModules[m.name.toString()] = m;
		}

		string linkInputFiles;
		foreach (name, _module; mModules) {
			foreach(pass; passes)
				pass.transform(_module);

			// this is just during bring up.
			string o = temporaryFilename(".bc");
			backend.setTarget(o, TargetType.LlvmBitcode);
			backend.compile(_module);
			linkInputFiles ~= " \"" ~ o ~ "\" ";
		}
		// close only after all uses
		backend.close();

		/// @todo Whoaaah, this shouldn't be here.
		string of = settings.outputFile is null ? DEFAULT_EXE : settings.outputFile;
		system(format("llvm-ld -native -o \"%s\" %s", of, linkInputFiles));
	}

public:
	this(Settings settings, Backend backend)
	{
		this.settings = settings;
		this.backend = backend;

		passes ~= new AttribRemoval();
		passes ~= new ConditionalRemoval(settings);
		passes ~= new ContextBuilder(this);
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
