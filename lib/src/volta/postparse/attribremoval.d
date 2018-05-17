/*#D*/
// Copyright 2012-2017, Bernard Helyer.
// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
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
void applyAttributes(ir.Import i, ref AttributeSink attrs, ErrorSink errSink)
{
	foreach (attr; attrs.borrowUnsafe()) {
		applyAttribute(i, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Function func, ref AttributeSink attrs, ErrorSink errSink, TargetInfo target)
{
	foreach (attr; attrs.borrowUnsafe()) {
		applyAttribute(func, attr, errSink, target);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.EnumDeclaration ed, ref AttributeSink attrs, ErrorSink errSink)
{
	foreach (attr; attrs.borrowUnsafe()) {
		applyAttribute(ed, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Variable d, ref AttributeSink attrs, ErrorSink errSink, TargetInfo target)
{
	foreach (attr; attrs.borrowUnsafe()) {
		applyAttribute(d, attr, errSink, target);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Aggregate s, ref AttributeSink attrs, ErrorSink errSink)
{
	foreach (attr; attrs.borrowUnsafe()) {
		applyAttribute(s, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir._Interface i, ref AttributeSink attrs, ErrorSink errSink)
{
	foreach (attr; attrs.borrowUnsafe()) {
		applyAttribute(i, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Enum e, ref AttributeSink attrs, ErrorSink errSink)
{
	foreach (attr; attrs.borrowUnsafe()) {
		applyAttribute(e, attr, errSink);
	}
}

/*!
 * Loops over all attributes and applies them.
 */
void applyAttributes(ir.Alias a, ref AttributeSink attrs, ErrorSink errSink)
{
	foreach (attr; attrs.borrowUnsafe()) {
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
	ContextSink mCtxStack;
	AttributeSink mAttrStack;

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
		AttributeSink stack;
		AttributeSink oldStack;
	}

	alias ContextSink = SinkStruct!Context;


public:
	this(TargetInfo target, ErrorSink errSink)
	{
		this.target = target;
		this.errSink = errSink;
	}


	/*
	 *
	 * Pass functions.
	 *
	 */

	override void transform(ir.Module m)
	{
		passert(errSink, m, mCtxStack.length == 0);
		passert(errSink, m, mAttrStack.length == 0);
		accept(m, this);
		mCtxStack.reset();
		mAttrStack.reset();
	}

	void transform(ir.Module m, ir.Function func, ir.BlockStatement bs)
	{
		passert(errSink, bs, mCtxStack.length == 0);
		passert(errSink, bs, mAttrStack.length == 0);

		// Just need to call enter on the module.
		enter(m);

		assert(func !is null);
		enter(func);

		accept(bs, this);

		assert(func !is null);
		leave(func);

		mCtxStack.reset();
		mAttrStack.reset();
	}

	override void close()
	{
	}


	/*
	 *
	 * Visitor functions.
	 *
	 */

	override Status enter(ir.Module m)
	{
		mCtxStack.sink(new Context(m));
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
		applyAttributes(i, /*#ref*/ctxTop.stack, errSink);
		applyAttributes(i, /*#ref*/mAttrStack, errSink);
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		applyAttributes(func, /*#ref*/ctxTop.stack, errSink, target);
		applyAttributes(func, /*#ref*/mAttrStack, errSink, target);
		ctxPush(func);
		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		applyAttributes(d, /*#ref*/ctxTop.stack, errSink, target);
		applyAttributes(d, /*#ref*/mAttrStack, errSink, target);
		return Continue;
	}

	override Status enter(ir.EnumDeclaration ed)
	{
		applyAttributes(ed, /*#ref*/ctxTop.stack, errSink);
		applyAttributes(ed, /*#ref*/mAttrStack, errSink);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		applyAttributes(s, /*#ref*/ctxTop.stack, errSink);
		applyAttributes(s, /*#ref*/mAttrStack, errSink);
		ctxPush(s);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		applyAttributes(u, /*#ref*/ctxTop.stack, errSink);
		applyAttributes(u, /*#ref*/mAttrStack, errSink);
		ctxPush(u);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		applyAttributes(c, /*#ref*/ctxTop.stack, errSink);
		applyAttributes(c, /*#ref*/mAttrStack, errSink);
		ctxPush(c);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		applyAttributes(i, /*#ref*/ctxTop.stack, errSink);
		applyAttributes(i, /*#ref*/mAttrStack, errSink);
		ctxPush(i);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		applyAttributes(e, /*#ref*/ctxTop.stack, errSink);
		applyAttributes(e, /*#ref*/mAttrStack, errSink);
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		applyAttributes(a, /*#ref*/ctxTop.stack, errSink);
		applyAttributes(a, /*#ref*/mAttrStack, errSink);
		return Continue;
	}

	override Status leave(ir.Function func) { ctxPop(func); return Continue; }
	override Status leave(ir.Struct s) { ctxPop(s); return Continue; }
	override Status leave(ir.Union u) { ctxPop(u); return Continue; }
	override Status leave(ir.Class c) { ctxPop(c); return Continue; }
	override Status leave(ir._Interface i) { ctxPop(i); return Continue; }
	override Status leave(ir.Module m) { mCtxStack.reset(); return Continue; }

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
	 *
	 * Stack functions.
	 *
	 */

	final @property Context ctxTop()
	{
		return mCtxStack.getLast();
	}

	final void ctxPush(ir.Node node, bool inherit = false)
	{
		auto ctx = new Context(node);

		ctx.oldStack.append(mAttrStack);

		if (inherit) {
			ctx.stack.append(ctxTop.stack);
			ctx.stack.append(mAttrStack);
		} else {
			ctx.stack.append(mAttrStack);
		}

		mCtxStack.sink(ctx);
		mAttrStack.reset(); // Stack has been saved.
	}

	final void ctxPop(ir.Node node)
	{
		while (mAttrStack.length > 0 && attrTop.members is null) {
			attrPop(attrTop);
		}

		if (node !is ctxTop.node) {
			panic(errSink, node, "invalid attribute stack layout");
			return;
		}

		mAttrStack = ctxTop.oldStack;
		mCtxStack.popLast();
	}

	final @property ir.Attribute attrTop()
	{
		return mAttrStack.getLast();
	}

	final void attrPush(ir.Attribute attr)
	{
		mAttrStack.sink(attr);
	}

	final void attrPop(ir.Attribute attr)
	{
		if (attrTop !is attr) {
			panic(errSink, attr, "invalid attribute stack layout");
			return;
		}
		mAttrStack.popLast();
	}

	final void attrPushDown()
	{
		ctxTop.stack.append(mAttrStack.borrowUnsafe());
	}


	/*
	 *
	 * Manip flattening code.
	 *
	 */

	final void manipAttr(ref NodeSink ns, ir.Attribute attr)
	{
		auto stack = [attr];
		attrPush(attr);

		// Take care of chaining.
		while (attr.chain !is null) {
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

	final ir.Node[] manip(ir.Node[] nodes)
	{
		NodeSink ns;
		manip(/*#ref*/ns, nodes);
		return ns.toArray();
	}

	final void manip(ref NodeSink ns, ir.Node[] nodes)
	{
		foreach (n; nodes) {
			manip(/*#ref*/ns, n);
		}
	}

	final void manip(ref NodeSink ns, ir.Node n)
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
}
