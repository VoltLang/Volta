// Copyright © 2014-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.jsonprinter;

import watt.io.streams : OutputFileStream;
import watt.text.utf : encode;

import ir = volt.ir.ir;
import volt.ir.printer;

import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;


class JsonPrinter : NullVisitor
{
private:
	bool mWriteComma;
	string mFilename;
	OutputFileStream mFile;


public:
	this(string filename)
	{
		this.mFilename = filename;
	}

	void transform(ir.Module[] mods...)
	{
		mFile = new OutputFileStream(mFilename);

		w("[");
		foreach (mod; mods) {
			accept(mod, this);
		}
		w("]");

		mFile.flush();
		mFile.close();
	}

	override Status enter(ir.Module m)
	{
		startObject();
		tag("kind", "module");
		tag("name", m.name.toString());
		tag("doc", m.docComment);
		startList("children");
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		if (s.loweredNode !is null) {
			return ContinueParent;
		}

		auto name = s.name;
		switch (name) {
		case "__Vtable": return ContinueParent;
		default: break;
		}

		startObject();
		tag("kind", "struct");
		tag("name", name);
		tag("doc", s.docComment);
		startList("children");
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		auto name = u.name;

		startObject();
		tag("kind", "union");
		tag("name", name);
		tag("doc", u.docComment);
		startList("children");
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		auto name = c.name;

		startObject();
		tag("kind", "class");
		tag("name", name);
		tag("doc", c.docComment);
		startList("children");

		return Continue;
	}

	override Status enter(ir.Function f)
	{
		bool suppressReturn;
		startObject();

		final switch(f.kind) with (ir.Function.Kind) {
		case Invalid: assert(false);
		case Function, LocalMember, GlobalMember, Nested, GlobalNested,
		     LocalConstructor, GlobalConstructor,
		     LocalDestructor, GlobalDestructor:
			tag("kind", "fn");
			tag("name", f.name);
			break;
		case Member:
			tag("kind", "member");
			tag("name", f.name);
			break;
		case Constructor:
			tag("kind", "ctor");
			suppressReturn = true;
			break;
		case Destructor:
			tag("kind", "dtor");
			suppressReturn = true;
			break;
		}

		tag("doc", f.docComment);

		if (f.params.length > 0) {
			startList("args");
			foreach (p; f.params) {
				startObject();
				writeNamedTyped(null, p.name, null, p.type);
				endObject();
			}
			endList();
		}

		if (!suppressReturn) {
			startList("rets");
			startObject();
			writeNamedTyped(null, null, null, f.type.ret);
			endObject();
			endList();
		}

		endObject();

		return ContinueParent;
	}

	override Status enter(ir.Variable v)
	{
		auto name = v.name;
		switch (name) {
		case "__cinit", "__vtable_instance": return ContinueParent;
		default: break;
		}

		startObject();
		writeNamedTyped("var", name, v.docComment, v.type);
		endObject();

		return ContinueParent;
	}

	override Status enter(ir.Enum e)
	{
		auto name = e.name;

		startObject();
		tag("kind", "enum");
		tag("name", name);
		tag("doc", e.docComment);
		endObject();

		return ContinueParent;
	}

	override Status leave(ir.Module) { endListAndObject(); return Continue; }
	override Status leave(ir.Struct) { endListAndObject(); return Continue; }
	override Status leave(ir.Union) { endListAndObject(); return Continue; }
	override Status leave(ir.Class) { endListAndObject(); return Continue; }


protected:
	void writeNamedTyped(string kind, string name, string doc, ir.Type type)
	{
		string typeFull, typeWritten;
		typeFull = printType(type);
		typeWritten = printType(type, true);

		if (typeWritten == typeFull) {
			typeFull = null;
		}

		tag("kind", kind);
		tag("name", name);
		tag("type", typeWritten);
		tag("typeFull", typeFull);
		tag("doc", doc);
	}

	void startObject()
	{
		wMaybeComma();
		w("{");
		mWriteComma = false;
	}

	void startList(string name)
	{
		wMaybeComma();
		wq(name);
		w(":[");
		mWriteComma = false;
	}

	void endObject()
	{
		w("}");
		mWriteComma = true;
	}

	void endList()
	{
		w("]");
		mWriteComma = true;
	}

	void endListAndObject()
	{
		w("]}");
		mWriteComma = true;
	}

	void tag(string tag, string value)
	{
		if (value.length == 0) {
			return;
		}

		wMaybeComma();
		wq(tag);
		w(":");
		wq(value);
		mWriteComma = true;
	}

	void w(string s)
	{
		mFile.writef(`%s`, s);
	}

	/// Add quotes to s and make it a JSON string (w/ escaping etc).
	void wq(string s)
	{
		char[] outString;
		foreach (dchar c; s) {
			switch (c) {
			case '"': outString ~= `\"`; break;
			case '\n': outString ~= `\n`; break;
			case '\r': outString ~= `\r`; break;
			case '\t': outString ~= `\t`; break;
			case '\f': outString ~= `\f`; break;
			case '\b': outString ~= `\b`; break;
			case '\\': outString ~= `\\` ; break;
			default: encode(outString, c); break;
			}
		}
		mFile.writef(`"%s"`, outString);
	}

	void wMaybeComma()
	{
		if (mWriteComma) {
			w(",\n");
		}
	}
}
