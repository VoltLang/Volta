// Copyright © 2014, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.docprinter;

import core.exception;

import watt.path : mkdir, dirName, dirSeparator;
import watt.io.streams : OutputFileStream;
import watt.text.format : format;
import watt.text.sink : StringSink;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.util.path : mkdirP;
import volt.visitor.visitor;


enum DEFAULT_STYLE = "
div.module { background: #eeeeee; }
div.struct { background: #ccffff; }
div.class { background: #ccffff; }
div.interface { background: #ccffff; }
div.union { background: #ccffff; }
div.uattr { background: #ccffff; }
div.variable { background: #ccffff; }
div.function { background: #ccffff; }
div.enum { background: #ccffff; }
div.enumdeclaration { background: #ccffff; }
";

class DocPrinter : NullVisitor, Pass
{
public:
	LanguagePass lp;

protected:
	OutputFileStream mHtmlFile;
	size_t mTransformCount;
	string mDocDir;
	string mDocOutput;

public:
	this(string docDir, string docOutput)
	{
		this.mDocDir = docDir;
		this.mDocOutput = docOutput;
	}

	override void transform(ir.Module m)
	{
		mTransformCount++;
		if (mDocDir.length > 0) {
			try {
				mkdir(mDocDir);
			} catch (Exception) {
			}
		}
		StringSink filenameSink;
		if (mDocDir.length != 0) {
			filenameSink.sink(mDocDir);
			filenameSink.sink(dirSeparator);
		}
		if (mDocOutput.length > 0) {
			filenameSink.sink(mDocOutput);
			if (mTransformCount >= 2) {
				throw makeExpected(m, "only one file with -do switch");
			}
		} else {
			foreach (i, ident; m.name.identifiers) {
				filenameSink.sink(ident.value);
				if (i < m.name.identifiers.length - 1) {
					filenameSink.sink(dirSeparator);
				}
			}
			filenameSink.sink(".html");

			mkdirP(dirName(filenameSink.toString()));
		}
		mHtmlFile = new OutputFileStream(filenameSink.toString());
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Module m)
	{
		writeHtmlOpening(format("Volt Documentation for Module %s", m.name));
		if (m.docComment.length == 0) {
			return Continue;
		}
		openTag(`div class="module"`);
		openTag("h3");
		mHtmlFile.write(format("module %s", m.name));
		closeTag("h3");
		outputComment(m);
		return Continue;
	}

	override Status leave(ir.Module m)
	{
		closeTag("div");
		writeHtmlClosing();
		mHtmlFile.close();
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		openTag(`div class="function"`);
		openTag("h3");
		mHtmlFile.writef("function %s", func.name);
		closeTag("h3");
		outputComment(func);
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		closeTag(`div`);
		return Continue;
	}

	override Status enter(ir.Variable var)
	{
		openTag(`div class="variable"`);
		openTag("h3");
		mHtmlFile.writef("variable %s", var.name);
		closeTag("h3");
		outputComment(var);
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.Alias _alias)
	{
		openTag(`div class="variable"`);
		openTag("h3");
		mHtmlFile.writef("alias %s", _alias.name);
		closeTag("h3");
		outputComment(_alias);
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.Struct _struct)
	{
		openTag(`div class="struct"`);
		openTag("h3");
		mHtmlFile.writef("struct %s", _struct.name);
		closeTag("h3");
		outputComment(_struct);
		return Continue;
	}

	override Status leave(ir.Struct _struct)
	{
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.Class _class)
	{
		openTag(`div class="class"`);
		openTag("h3");
		mHtmlFile.writef("class %s", _class.name);
		closeTag("h3");
		outputComment(_class);
		return Continue;
	}

	override Status leave(ir.Class _class)
	{
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.Union _union)
	{
		openTag(`div class="union"`);
		openTag("h3");
		mHtmlFile.writef("union %s", _union.name);
		closeTag("h3");
		outputComment(_union);
		return Continue;
	}

	override Status leave(ir.Union _union)
	{
		closeTag("div");
		return Continue;
	}

	override Status enter(ir._Interface _interface)
	{
		openTag(`div class="interface"`);
		openTag("h3");
		mHtmlFile.writef("interface %s", _interface.name);
		closeTag("h3");
		outputComment(_interface);
		return Continue;
	}

	override Status leave(ir._Interface _interface)
	{
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.UserAttribute uattr)
	{
		openTag(`div class="uattr"`);
		openTag("h3");
		mHtmlFile.writef("user attribute %s", uattr.name);
		closeTag("h3");
		outputComment(uattr);
		return Continue;
	}

	override Status leave(ir.UserAttribute uattr)
	{
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.Enum _enum)
	{
		openTag(`div class="enum"`);
		openTag("h3");
		mHtmlFile.writef("enum %s", _enum.name);
		closeTag("h3");
		outputComment(_enum);
		return Continue;
	}

	override Status leave(ir.Enum _enum)
	{
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.EnumDeclaration edecl)
	{
		openTag(`div class="enumdeclaration"`);
		openTag("h3");
		mHtmlFile.writef("%s", edecl.name);
		closeTag("h3");
		outputComment(edecl);
		closeTag("div");
		return Continue;
	}

protected:
	void outputComment(ir.Node node)
	{
		mHtmlFile.writefln("<pre>%s</pre>", node.docComment);
	}

	void openTag(string tag)
	{
		mHtmlFile.writef("<%s>", tag);
	}

	void closeTag(string tag)
	{
		mHtmlFile.writefln("</%s>", tag);
	}

	void writeHtmlOpening(string title)
	{
		wln("<!DOCTYPE html>");

		openTag("html lang=\"en\"");
		openTag("head");
		wln(`<meta charset="UTF-8">`);
		openTag("title");
		wln(title);
		closeTag("title");
		openTag("style");
		w(DEFAULT_STYLE);
		closeTag("style");
		closeTag("head");
		openTag("body");
	}

	void writeHtmlClosing()
	{
		closeTag("body");
		closeTag("html");
	}

	void w(string f)
	{
		mHtmlFile.writef("%s", f);
	}

	void wln(string f)
	{
		mHtmlFile.writef("%s", f);
	}
}
