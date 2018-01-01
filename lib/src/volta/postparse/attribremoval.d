/*#D*/
// Copyright © 2012-2017, Bernard Helyer.
// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Code that flattens volt attributes onto ir nodes.
 *
 * @ingroup passPost
 */
module volta.postparse.attribremoval;

import ir = volta.ir;

import volta.errors;
import volta.interfaces;
import volta.util.util;
import volta.util.sinks;
import volta.visitor.visitor;


/*
 *
 * Attribute application code.
 *
 */

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Import i, ir.Attribute[] attrs, ErrorSink errSink)
{
	foreach (attr; attrs) {
		applyAttribute(i, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Function func, ir.Attribute[] attrs, ErrorSink errSink, TargetInfo target)
{
	foreach (attr; attrs) {
		applyAttribute(func, attr, errSink, target);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.EnumDeclaration ed, ir.Attribute[] attrs, ErrorSink errSink)
{
	foreach (attr; attrs) {
		applyAttribute(ed, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Variable d, ir.Attribute[] attrs, ErrorSink errSink, TargetInfo target)
{
	foreach (attr; attrs) {
		applyAttribute(d, attr, errSink, target);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Aggregate s, ir.Attribute[] attrs, ErrorSink errSink)
{
	foreach (attr; attrs) {
		applyAttribute(s, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir._Interface i, ir.Attribute[] attrs, ErrorSink errSink)
{
	foreach (attr; attrs) {
		applyAttribute(i, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Enum e, ir.Attribute[] attrs, ErrorSink errSink)
{
	foreach (attr; attrs) {
		applyAttribute(e, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Alias a, ir.Attribute[] attrs, ErrorSink errSink)
{
	foreach (attr; attrs) {
		applyAttribute(a, attr, errSink);
	}
}

/*!
 * Applies a single attribute.
 */
void applyAttribute(ir.Import i, ir.Attribute attr, ErrorSink errSink)
{
	switch(attr.kind) with (ir.Attribute.Kind) {
	case Public:
		i.access = ir.Access.Public;
		break;
	case Private:
		i.access = ir.Access.Private;
		break;
	case Protected:
		i.access = ir.Access.Protected;
		break;
	case Static:
		i.isStatic = true;
		break;
	default:
		// Warn?
	}
}

/*!
 * Applies a single attribute.
 */
void applyAttribute(ir.Function func, ir.Attribute attr, ErrorSink errSink, TargetInfo target)
{
	switch(attr.kind) with (ir.Attribute.Kind) {
	case LinkageVolt:
		func.type.linkage = ir.Linkage.Volt;
		break;
	case LinkageC:
		func.type.linkage = ir.Linkage.C;
		break;
	case LinkageCPlusPlus:
		func.type.linkage = ir.Linkage.CPlusPlus;
		break;
	case LinkageWindows:
		func.type.linkage = ir.Linkage.Windows;
		break;
	case LinkagePascal:
		func.type.linkage = ir.Linkage.Pascal;
		break;
	case LinkageSystem:
		if (target.platform == Platform.MinGW) {
			func.type.linkage = ir.Linkage.Windows;
		} else {
			func.type.linkage = ir.Linkage.C;
		}
		break;
	case LoadDynamic:
		func.loadDynamic = true;
		break;
	case Public:
		func.access = ir.Access.Public;
		break;
	case Private:
		func.access = ir.Access.Private;
		break;
	case Protected:
		func.access = ir.Access.Protected;
		break;
	case Scope:
		func.type.isScope = true;
		break;
	case Property:
		func.type.isProperty = true;
		break;
	case Override:
		func.isMarkedOverride = true;
		break;
	case Abstract:
		func.isAbstract = true;
		break;
	case Final:
		func.isFinal = true;
		break;
	case Static: // TODO (selfhost) remove.
	case Local, Global:
		with (ir.Function.Kind) {
		if (func.kind == Constructor ||
		    func.kind == Destructor) {
			// We do not make (con|de)structors like this.
		} else {
			func.kind = ir.Function.Kind.Function;
		}
		} // with
		break;
	case MangledName:
		if (!passert(errSink, attr, attr.arguments.length == 1)) {
			return;
		}
		auto constant = cast(ir.Constant) attr.arguments[0];
		if (constant is null || constant._string.length <= 2 || constant._string[0] != '\"') {
			errorExpected(errSink, attr, "non empty string literal argument to MangledName.");
			return;
		}
		if (!passert(errSink, constant, constant._string[0] == '\"') ||
			!passert(errSink, constant, constant._string[$-1] == '\"')) {
			return;
		}
		func.mangledName = constant._string[1..$-1];
		break;
	case Label:
		func.type.forceLabel = true;
		break;
	default:
		// Warn?
	}
}

/*!
 * Applies a single attribute.
 */
void applyAttribute(ir.EnumDeclaration ed, ir.Attribute attr, ErrorSink errSink)
{
	switch(attr.kind) with (ir.Attribute.Kind) {
	case Public:
		ed.access = ir.Access.Public;
		break;
	case Private:
		ed.access = ir.Access.Private;
		break;
	case Protected:
		ed.access = ir.Access.Protected;
		break;
	default:
		// Warn?
	}
}

/*!
 * Applies a single attribute.
 */
void applyAttribute(ir.Variable d, ir.Attribute attr, ErrorSink errSink, TargetInfo target)
{
	switch(attr.kind) with (ir.Attribute.Kind) {
	case Public:
		d.access = ir.Access.Public;
		break;
	case Private:
		d.access = ir.Access.Private;
		break;
	case Protected:
		d.access = ir.Access.Protected;
		break;
	case Static:
	case Global:
		d.storage = ir.Variable.Storage.Global;
		break;
	case Local:
		d.storage = ir.Variable.Storage.Local;
		break;
	case LinkageVolt:
		d.linkage = ir.Linkage.Volt;
		break;
	case LinkageC:
		d.linkage = ir.Linkage.C;
		break;
	case LinkageCPlusPlus:
		d.linkage = ir.Linkage.CPlusPlus;
		break;
	case LinkageWindows:
		d.linkage = ir.Linkage.Windows;
		break;
	case LinkagePascal:
		d.linkage = ir.Linkage.Pascal;
		break;
	case LinkageSystem:
		if (target.platform == Platform.MinGW) {
			d.linkage = ir.Linkage.Windows;
		} else {
			d.linkage = ir.Linkage.C;
		}
		break;
	case Extern:
		d.isExtern = true;
		break;
	case MangledName:
		if (!passert(errSink, attr, attr.arguments.length == 1)) {
			return;
		}
		auto constant = cast(ir.Constant) attr.arguments[0];
		if (constant is null || constant._string.length <= 2 || constant._string[0] != '\"') {
			errorExpected(errSink, attr, "non empty string literal argument to MangledName.");
			passert(errSink, attr, false);
			return;
		}
		if (!passert(errSink, attr, constant._string[0] == '\"') ||
		    !passert(errSink, attr, constant._string[$-1] == '\"')) {
			return;
		}
		d.mangledName = constant._string[1..$-1];
		break;
	default:
		// Warn?
	}
}

/*!
 * Applies a single attribute.
 */
void applyAttribute(ir.Aggregate s, ir.Attribute attr, ErrorSink errSink)
{
	switch(attr.kind) with (ir.Attribute.Kind) {
	case Public:
		s.access = ir.Access.Public;
		break;
	case Private:
		s.access = ir.Access.Private;
		break;
	case Protected:
		s.access = ir.Access.Protected;
		break;
	case Abstract:
		auto c = cast(ir.Class) s;
		if (c is null) {
			errorMsg(errSink, s, badAbstractMsg());
			return;
		}
		c.isAbstract = true;
		break;
	case Final:
		auto c = cast(ir.Class) s;
		if (c is null) {
			errorMsg(errSink, s, badFinalMsg());
			return;
		}
		c.isFinal = true;
		break;
	default:
		// Warn?
	}
}

/*!
 * Applies a single attribute.
 */
void applyAttribute(ir._Interface i, ir.Attribute attr, ErrorSink errSink)
{
	switch(attr.kind) with (ir.Attribute.Kind) {
	case Public:
		i.access = ir.Access.Public;
		break;
	case Private:
		i.access = ir.Access.Private;
		break;
	case Protected:
		i.access = ir.Access.Protected;
		break;
	default:
		// Warn?
	}
}

/*!
 * Applies a single attribute.
 */
void applyAttribute(ir.Enum e, ir.Attribute attr, ErrorSink errSink)
{
	switch(attr.kind) with (ir.Attribute.Kind) {
	case Public:
		e.access = ir.Access.Public;
		break;
	case Private:
		e.access = ir.Access.Private;
		break;
	case Protected:
		e.access = ir.Access.Protected;
		break;
	default:
		// Warn?
	}
}

/*!
 * Applies a single attribute.
 */
void applyAttribute(ir.Alias a, ir.Attribute attr, ErrorSink errSink)
{
	switch(attr.kind) with (ir.Attribute.Kind) {
	case Public:
		a.access = ir.Access.Public;
		break;
	case Private:
		a.access = ir.Access.Private;
		break;
	case Protected:
		a.access = ir.Access.Protected;
		break;
	default:
		// Warn?
	}
}


/*
 *
 * Visitor code.
 *
 */

/*!
 * A pass that turns Attributes nodes into fields on to
 * Functions, Classes and the like.
 *
 * @ingroup passes passLang passPost
 */
class AttribRemoval : NullVisitor, Pass
{
public:
	TargetInfo target;
	ErrorSink errSink;


protected:
	ir.Attribute[] mStack;
	Context[] mCtx;

	/*!
	 * Helper class.
	 */
	static class Context
	{
		this(ir.Node node)
		{
			this.node = node;
		}

		ir.Node node;
		ir.Attribute[] stack;
		ir.Attribute[] oldStack;
	}


public:
	this(TargetInfo target, ErrorSink errSink)
	{
		this.target = target;
		this.errSink = errSink;
	}

	/*
	 * Things that do stuff.
	 */
	override Status enter(ir.Module m)
	{
		mCtx = [new Context(m)];
		return Continue;
	}

	override Status enter(ir.TopLevelBlock tlb)
	{
		// Filter out any Attributes.
		tlb.nodes = manip(tlb.nodes);
		return ContinueParent;
	}

	override Status enter(ir.Import i)
	{
		applyAttributes(i, ctxTop.stack, errSink);
		applyAttributes(i, mStack, errSink);
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		applyAttributes(func, ctxTop.stack, errSink, target);
		applyAttributes(func, mStack, errSink, target);
		ctxPush(func);
		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		applyAttributes(d, ctxTop.stack, errSink, target);
		applyAttributes(d, mStack, errSink, target);
		return Continue;
	}

	override Status enter(ir.EnumDeclaration ed)
	{
		applyAttributes(ed, ctxTop.stack, errSink);
		applyAttributes(ed, mStack, errSink);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		applyAttributes(s, ctxTop.stack, errSink);
		applyAttributes(s, mStack, errSink);
		ctxPush(s);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		applyAttributes(u, ctxTop.stack, errSink);
		applyAttributes(u, mStack, errSink);
		ctxPush(u);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		applyAttributes(c, ctxTop.stack, errSink);
		applyAttributes(c, mStack, errSink);
		ctxPush(c);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		applyAttributes(i, ctxTop.stack, errSink);
		applyAttributes(i, mStack, errSink);
		ctxPush(i);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		applyAttributes(e, ctxTop.stack, errSink);
		applyAttributes(e, mStack, errSink);
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		applyAttributes(a, ctxTop.stack, errSink);
		applyAttributes(a, mStack, errSink);
		return Continue;
	}

	override Status leave(ir.Function func) { ctxPop(func); return Continue; }
	override Status leave(ir.Struct s) { ctxPop(s); return Continue; }
	override Status leave(ir.Union u) { ctxPop(u); return Continue; }
	override Status leave(ir.Class c) { ctxPop(c); return Continue; }
	override Status leave(ir._Interface i) { ctxPop(i); return Continue; }

	override Status enter(ir.Attribute attr) { passert(errSink, attr, false); return Continue; }
	override Status leave(ir.Attribute attr) { passert(errSink, attr, false); return Continue; }

	override Status visit(ir.TemplateDefinition td)
	{
		if (td._struct !is null) {
			return accept(td._struct, this);
		}
		if (td._union !is null) {
			return accept(td._union, this);
		}
		if (td._interface !is null) {
			return accept(td._interface, this);
		}
		if (td._class !is null) {
			return accept(td._class, this);
		}
		if (td._function !is null) {
			return accept(td._function, this);
		}
		panic(errSink, td, "Invalid TemplateDefinition");
		return Continue;
	}


protected:
	/*
	 * Apply functions.
	 */


	@property Context ctxTop()
	{
		return mCtx[$-1];
	}

	void ctxPush(ir.Node node, bool inherit = false)
	{
		auto ctx = new Context(node);

		ctx.node = node;
		ctx.oldStack = this.mStack;

		if (inherit) {
			ctx.stack = ctxTop.stack ~ mStack;
		} else {
			ctx.stack = mStack;
		}

		mCtx ~= ctx;
		mStack = null; // Stack has been saved.
	}

	void ctxPop(ir.Node node)
	{
		while (mStack.length > 0 && attrTop.members is null) {
			attrPop(attrTop);
		}

		if (node !is ctxTop.node) {
			panic(errSink, node, "invalid attribute stack layout");
			return;
		}

		mStack = ctxTop.oldStack;
		mCtx = mCtx[0 .. $-1];
	}

	@property ir.Attribute attrTop()
	{
		return mStack[$-1];
	}

	void attrPush(ir.Attribute attr)
	{
		mStack ~= attr;
	}

	void attrPop(ir.Attribute attr)
	{
		if (attrTop !is attr) {
			panic(errSink, attr, "invalid attribute stack layout");
			return;
		}
		mStack = mStack[0 .. $-1];
	}

	void attrPushDown()
	{
		mCtx[$-1].stack ~= mStack;
	}

	void manipAttr(ref NodeSink ns, ir.Attribute attr)
	{
		auto stack = [attr];
		attrPush(attr);

		// Take care of chaining.
		while(attr.chain !is null) {
			attr = attr.chain;
			attrPush(attr);
			stack ~= attr;
		}

		if (attr.members is null) {
			return;
		}

		scope (exit) {
			if (attr.members.nodes.length > 0) {
				ctxPop(attr);
			}
			foreach_reverse(a; stack) {
				attrPop(a);
			}
		}

		if (attr.members.nodes.length > 0) {
			ctxPush(attr, true);
			return manip(/*#ref*/ns, attr.members.nodes);
		}
	}


	/*
	 *
	 * Manip flattening code.
	 *
	 */

	ir.Node[] manip(ir.Node[] nodes)
	{
		NodeSink ns;
		manip(/*#ref*/ns, nodes);
		return ns.toArray();
	}

	void manip(ref NodeSink ns, ir.Node[] nodes)
	{
		foreach (n; nodes) {
			manip(/*#ref*/ns, n);
		}
	}

	void manip(ref NodeSink ns, ir.Node n)
	{
		switch (n.nodeType) with (ir.NodeType) {
		case Attribute:
			auto attr = n.toAttributeFast();
			manipAttr(/*#ref*/ns, attr);
			break;
		default:
			accept(n, this);
			ns.sink(n);
			break;
		}
	}


public:
	/*
	 * Pass.
	 */
	override void transform(ir.Module m)
	{
		passert(errSink, m, mStack.length == 0);
		passert(errSink, m, mCtx.length == 0);
		accept(m, this);
		mStack = null;
		mCtx = null;
	}

	override void close()
	{
	}
}
