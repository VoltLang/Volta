// Copyright © 2014, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.docprinter;

import std.stdio;
import std.string;
import std.path;
import std.file : mkdir;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.errors;
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
	File mHtmlFile;
	size_t mTransformCount;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	override void transform(ir.Module m)
	{
		mTransformCount++;
		if (lp.settings.docDir.length > 0) {
			try {
				mkdir(lp.settings.docDir);
			} catch (Exception) {
			}
		}
		char[] filename = lp.settings.docDir.length == 0 ? "".dup : (lp.settings.docDir ~ dirSeparator).dup;
		if (lp.settings.docOutput.length > 0) {
			filename ~= lp.settings.docOutput.dup;
			if (mTransformCount >= 2) {
				throw makeExpected(m, "only one file with -do switch");
			}
		} else foreach (i, ident; m.name.identifiers) {
			filename ~= ident.value;
			if (i < m.name.identifiers.length - 1) {
				filename ~= dirSeparator;
			}
			filename ~= ".html";
		}
		mHtmlFile.open(filename.idup, "w");
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

	override Status enter(ir.Function fn)
	{
		openTag(`div class="function"`);
		openTag("h3");
		mHtmlFile.write(format("function %s", fn.name));
		closeTag("h3");
		outputComment(fn);
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		closeTag(`div`);
		return Continue;
	}

	override Status enter(ir.Variable var)
	{
		openTag(`div class="variable"`);
		openTag("h3");
		mHtmlFile.write(format("variable %s", var.name));
		closeTag("h3");
		outputComment(var);
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.Alias _alias)
	{
		openTag(`div class="variable"`);
		openTag("h3");
		mHtmlFile.write(format("alias %s", _alias.name));
		closeTag("h3");
		outputComment(_alias);
		closeTag("div");
		return Continue;
	}

	override Status enter(ir.Struct _struct)
	{
		openTag(`div class="struct"`);
		openTag("h3");
		mHtmlFile.write(format("struct %s", _struct.name));
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
		mHtmlFile.write(format("class %s", _class.name));
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
		mHtmlFile.write(format("union %s", _union.name));
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
		mHtmlFile.write(format("interface %s", _interface.name));
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
		mHtmlFile.write(format("user attribute %s", uattr.name));
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
		mHtmlFile.write(format("enum %s", _enum.name));
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
		mHtmlFile.write(format("%s", edecl.name));
		closeTag("h3");
		outputComment(edecl);
		closeTag("div");
		return Continue;
	}

protected:
	void outputComment(ir.Node node)
	{
		mHtmlFile.writeln("<pre>", node.docComment, "</pre>");
	}

	void openTag(string tag)
	{
		mHtmlFile.write("<" ~ tag ~ ">");
	}

	void closeTag(string tag)
	{
		mHtmlFile.writeln("</" ~ tag ~ ">");
	}

	void writeHtmlOpening(string title)
	{
		mHtmlFile.writeln("<!DOCTYPE html>");

		openTag("html lang=\"en\"");
		openTag("head");
		mHtmlFile.writeln(`<meta charset="UTF-8">`);
		openTag("title");
		mHtmlFile.writeln(title);
		closeTag("title");
		openTag("style");
		mHtmlFile.write(DEFAULT_STYLE);
		closeTag("style");
		closeTag("head");
		openTag("body");
	}

	void writeHtmlClosing()
	{
		closeTag("body");
		closeTag("html");
	}
}