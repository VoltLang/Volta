// Copyright © 2014-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.jsonprinter;

import watt.conv : toString;
import watt.io.streams : OutputFileStream;
import watt.text.utf : encode;
import watt.text.sink;

import ir = volt.ir.ir;
import volt.ir.printer;

import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.classify;


class JsonPrinter : NullVisitor
{
private:
	bool mWriteComma;
	string mFilename;
	OutputFileStream mFile;
	string[] mGlobalDocComments;


public:
	this(string filename)
	{
		this.mFilename = filename;
	}

	void transform(TargetInfo target, ir.Module[] mods...)
	{
		mFile = new OutputFileStream(mFilename);

		w("{");
		writeTargetInfo(target);
		startList("modules");
		foreach (mod; mods) {
			accept(mod, this);
		}
		endList();
		startList("globalDocComments");
		foreach (doc; mGlobalDocComments) {
			wMaybeComma();
			wq(doc);
			mWriteComma = true;
		}
		endList();
		w("}");

		mFile.flush();
		mFile.close();
	}

	override Status enter(ir.Module m)
	{
		// Collect all of the global doc comments.
		mGlobalDocComments ~= m.globalDocComments;

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
		tag("mangledName", s.mangledName);
		tag("doc", s.docComment);
		tag("access", ir.accessToString(s.access));
		startList("children");
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		auto name = u.name;

		startObject();
		tag("kind", "union");
		tag("name", name);
		tag("mangledName", u.mangledName);
		tag("doc", u.docComment);
		tag("access", ir.accessToString(u.access));
		startList("children");
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		auto name = c.name;

		startObject();
		tag("kind", "class");
		if (c.parent !is null) {
			tag("parent", c.parent.toString());
			tag("parentFull", printType(c.parentClass));
		}
		if (c.interfaces.length > 0) {
			startList("interfaces");
			foreach (i, _if; c.interfaces) {
				wq(_if.toString());
				if (i < c.interfaces.length - 1) {
					w(",\n");
				}
			}
			endList();
			startList("interfacesFull");
			foreach (i, _if; c.parentInterfaces) {
				wq(printType(_if));
				if (i < c.parentInterfaces.length - 1) {
					w(",\n");
				}
			}
			endList();
		}
		tag("name", name);
		tag("mangledName", c.mangledName);
		tag("doc", c.docComment);
		tag("access", ir.accessToString(c.access));
		tag("isAbstract", c.isAbstract);
		tag("isFinal", c.isFinal);
		startList("children");

		return Continue;
	}

	override Status enter(ir._Interface ifc)
	{
		auto name = ifc.name;

		startObject();
		tag("kind", "interface");
		tag("name", name);
		tag("mangledName", ifc.mangledName);
		if (ifc.interfaces.length > 0) {
			startList("parents");
			foreach (i, _if; ifc.interfaces) {
				wq(_if.toString());
				if (i < ifc.interfaces.length - 1) {
					w(",\n");
				}
			}
			endList();
			startList("parentsFull");
			foreach (i, _if; ifc.parentInterfaces) {
				wq(printType(_if));
				if (i < ifc.parentInterfaces.length - 1) {
					w(",\n");
				}
			}
			endList();
		}
		tag("doc", ifc.docComment);
		tag("access", ir.accessToString(ifc.access));
		startList("children");

		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		auto name = a.name;
		startObject();
		if (a.type is null) {
			tag("kind", "alias");
			tag("name", a.name);
			tag("type", a.id.toString());
		} else {
			writeNamedTyped("alias", name, a.docComment, a.type);
		}
		tag("access", ir.accessToString(a.access));
		endObject();
		return ContinueParent;
	}

	override Status enter(ir.Import i)
	{
		startObject();
		tag("kind", "import");
		tag("access", ir.accessToString(i.access));
		tag("isStatic", i.isStatic);
		tag("name", i.name.toString());
		if (i.bind !is null) {
			tag("bind", i.bind.value);
		}
		if (i.aliases.length > 0) {
			startList("aliases");
			foreach (j, _alias; i.aliases) {
				w("[");
				wq(_alias[0].value);
				if (_alias[1] !is null) {
					w(",\n");
					wq(_alias[1].value);
				}
				w("]");
				if (j < i.aliases.length - 1) {
					w(",\n");
				}
			}
			endList();
		}
		endObject();
		return ContinueParent;
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
		tag("mangledName", f.mangledName);

		tag("doc", f.docComment);
		tag("linkage", ir.linkageToString(f.type.linkage));

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

		tag("hasBody", f._body !is null);
		tag("access", ir.accessToString(f.access));
		tag("isScope", f.type.isScope);
		tag("isProperty", f.type.isProperty);
		tag("isOverride", f.isMarkedOverride);
		tag("isAbstract", f.isAbstract);
		tag("isFinal", f.isFinal);
		tag("forceLabel", f.type.forceLabel);

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
		if (name.length > 4 && name[0 .. 4] == "_V__" ||
		    printType(v.type, true) == "__ifaceVtable") {
			return ContinueParent;
		}

		startObject();
		writeNamedTyped("var", name, v.docComment, v.type);
		tag("mangledName", v.mangledName);
		tag("access", ir.accessToString(v.access));
		tag("linkage", ir.linkageToString(v.linkage));
		tag("storage", ir.Variable.storageToString(v.storage));
		tag("isExtern", v.isExtern);
		endObject();

		return ContinueParent;
	}

	override Status enter(ir.Enum e)
	{
		auto name = e.name;

		startObject();
		tag("kind", "enum");
		tag("name", name);
		tag("mangledName", e.mangledName);
		tag("doc", e.docComment);
		tag("access", ir.accessToString(e.access));
		startList("children");

		return Continue;
	}

	override Status enter(ir.EnumDeclaration ed)
	{
		auto name = ed.name;
		startObject();
		writeNamedTyped("enumdecl", name, ed.docComment, ed.type);
		auto constant = cast(ir.Constant)ed.assign;
		if (isIntegral(ed.type) && constant !is null) {
			tag("value", .toString(constant.u._int));
		}
		if (ed.isStandalone) {
			tag("access", ir.accessToString(ed.access));
		}
		tag("isStandalone", ed.isStandalone);
		endObject();
		return ContinueParent;
	}

	override Status leave(ir.Module) { endListAndObject(); return Continue; }
	override Status leave(ir.Struct) { endListAndObject(); return Continue; }
	override Status leave(ir.Union) { endListAndObject(); return Continue; }
	override Status leave(ir.Class) { endListAndObject(); return Continue; }
	override Status leave(ir.Enum) { endListAndObject(); return Continue; }
	override Status leave(ir._Interface) { endListAndObject(); return Continue; }


protected:
	void writeTargetInfo(TargetInfo target)
	{
		startObject("target");
		tag("arch", archToString(target.arch));
		tag("platform", platformToString(target.platform));
		tag("isP64", target.isP64);
		tag("ptrSize", target.ptrSize);
		writeAlignments(target.alignment);
		endObject();
	}

	void writeAlignments(TargetInfo.Alignments alignment)
	{
		startObject("alignment");
		tag("int1", alignment.int1);
		tag("int8", alignment.int8);
		tag("int16", alignment.int16);
		tag("int32", alignment.int32);
		tag("int64", alignment.int64);
		tag("float32", alignment.float32);
		tag("float64", alignment.float64);
		tag("ptr", alignment.ptr);
		tag("aggregate", alignment.aggregate);
		endObject();
	}

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

	void startObject(string name)
	{
		wMaybeComma();
		wq(name);
		w(":{");
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

	void tag(string tag, bool value)
	{
		if (!value) {
			return;
		}
		wMaybeComma();
		wq(tag);
		w(":");
		w(value ? "true" : "false");
		mWriteComma = true;
	}

	void tag(string tag, size_t n)
	{
		wMaybeComma();
		wq(tag);
		w(":");
		w(.toString(n));
		mWriteComma = true;
	}

	void w(SinkArg s)
	{
		version (Volt) {
			mFile.write(s);
		} else {
			mFile.writef(`%s`, s);
		}
	}

	//! Add quotes to s and make it a JSON string (w/ escaping etc).
	void wq(string s)
	{
		w(`"`);
		foreach (dchar c; s) {
			switch (c) {
			case '"': w(`\"`); break;
			case '\n': w(`\n`); break;
			case '\r': w(`\r`); break;
			case '\t': w(`\t`); break;
			case '\f': w(`\f`); break;
			case '\b': w(`\b`); break;
			case '\\': w(`\\`); break;
			default:
				version (Volt) {
					encode(w, c);
				} else {
					char[] outString;
					encode(outString, c);
					w(outString);
				}
				break;
			}
		}
		w(`"`);
	}

	void wMaybeComma()
	{
		if (mWriteComma) {
			w(",\n");
		}
	}
}
