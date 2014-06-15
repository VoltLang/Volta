// Copyright © 2014, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.jsonprinter;

import std.stdio;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.errors;
import volt.visitor.visitor;

private struct Entry
{
	string name;
	string comment;
}

class JsonPrinter : NullVisitor
{
public:
	LanguagePass lp;
	Entry[] functions, variables, enums, structs, classes;
	ir.Module currentModule;
	File fp;

	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	void transform(ir.Module[] modules...)
	{
		foreach (mod; modules) {
			currentModule = mod;
			accept(mod, this);
		}
		fp.open(lp.settings.jsonOutput, "w");
		w("{\n");
		writeArray("functions", functions, ",\n");
		writeArray("variables", variables, ",\n");
		writeArray("enums", enums, ",\n");
		writeArray("structs", structs, ",\n");
		writeArray("classes", classes, "\n");
		w("}\n");
	}

	override Status enter(ir.Function fn)
	{
		if (fn.docComment.length > 0) {
			functions ~= Entry(currentModule.name.toString() ~ "." ~ fn.name, fn.docComment);
		}
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		if (v.docComment.length > 0) {
			variables ~= Entry(currentModule.name.toString() ~ "." ~ v.name, v.docComment);
		}
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		if (e.docComment.length > 0) {
			enums ~= Entry(currentModule.name.toString() ~ "." ~ e.name, e.docComment);
		}
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		if (s.docComment.length > 0) {
			structs ~= Entry(currentModule.name.toString() ~ "." ~ s.name, s.docComment);
		}
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		if (c.docComment.length > 0) {
			classes ~= Entry(currentModule.name.toString() ~ "." ~ c.name, c.docComment);
		}
		return Continue;
	}

private:
	void writeArray(string entryName, Entry[] entries, string end)
	{
		wq(entryName);
		w(": [");
		foreach (i, n; entries) {
			w("[");
			wq(n.name);
			w(", ");
			wq(n.comment);
			w("]");
			w((i == entries.length - 1) ? "" : ",");
		}
		w("]" ~ end);
	}

	void w(string s)
	{
		fp.writef(`%s`, s);
	}

	/// Add quotes to s and make it a JSON string (w/ escaping etc).
	void wq(string s)
	{
		char[] outString;
		foreach (c; s) {
			switch (c) {
			case '"': outString ~= `\"`; break;
			case '\n': outString ~= `\n`; break;
			case '\r': outString ~= `\r`; break;
			case '\t': outString ~= `\t`; break;
			case '\f': outString ~= `\f`; break;
			case '\b': outString ~= `\b`; break;
			case '\\': outString ~= `\\` ; break;
			default: outString ~= c; break;
			}
		}
		fp.writef(`"%s"`, outString);
	}
}
