// Copyright © 2012-2017, Bernard Helyer.
// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Code that flattens volt attributes onto ir nodes.
 *
 * @ingroup passPost
 */
module volt.postparse.attribremoval;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.visitor.manip;
import volt.visitor.visitor;


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
	this(TargetInfo target)
	{
		this.target = target;
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
		version (Volt) {
			tlb.nodes = manipNodes(tlb.nodes, nodeManipDg);
		} else {
			tlb.nodes = manipNodes(tlb.nodes, &nodeManipDg);
		}
		return ContinueParent;
	}

	override Status enter(ir.Import i)
	{
		applyAttributes(i, ctxTop.stack);
		applyAttributes(i, mStack);
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		applyAttributes(func, ctxTop.stack);
		applyAttributes(func, mStack);
		ctxPush(func);
		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		applyAttributes(d, ctxTop.stack);
		applyAttributes(d, mStack);
		return Continue;
	}

	override Status enter(ir.EnumDeclaration ed)
	{
		applyAttributes(ed, ctxTop.stack);
		applyAttributes(ed, mStack);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		applyAttributes(s, ctxTop.stack);
		applyAttributes(s, mStack);
		ctxPush(s);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		applyAttributes(u, ctxTop.stack);
		applyAttributes(u, mStack);
		ctxPush(u);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		applyAttributes(c, ctxTop.stack);
		applyAttributes(c, mStack);
		ctxPush(c);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		applyAttributes(i, ctxTop.stack);
		applyAttributes(i, mStack);
		ctxPush(i);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		applyAttributes(e, ctxTop.stack);
		applyAttributes(e, mStack);
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		applyAttributes(a, ctxTop.stack);
		applyAttributes(a, mStack);
		return Continue;
	}

	override Status leave(ir.Function func) { ctxPop(func); return Continue; }
	override Status leave(ir.Struct s) { ctxPop(s); return Continue; }
	override Status leave(ir.Union u) { ctxPop(u); return Continue; }
	override Status leave(ir.Class c) { ctxPop(c); return Continue; }
	override Status leave(ir._Interface i) { ctxPop(i); return Continue; }

	override Status enter(ir.Attribute attr) { assert(false); }
	override Status leave(ir.Attribute attr) { assert(false); }

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
		throw panic("Invalid TemplateDefinition");
	}


protected:
	/*
	 * Apply functions.
	 */

	/*!
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Import i, ir.Attribute[] attrs)
	{
		foreach (attr; attrs) {
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
	}

	/*!
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Function func, ir.Attribute[] attrs)
	{
		foreach (attr; attrs) {
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
				assert(attr.arguments.length == 1);
				auto constant = cast(ir.Constant) attr.arguments[0];
				if (constant is null || constant._string.length <= 2 || constant._string[0] != '\"') {
					throw makeExpected(attr, "non empty string literal argument to MangledName.");
				}
				assert(constant._string[0] == '\"');
				assert(constant._string[$-1] == '\"');
				func.mangledName = constant._string[1..$-1];
				break;
			case Label:
				func.type.forceLabel = true;
				break;
			default:
				// Warn?
			}
		}
	}

	/*!
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.EnumDeclaration ed, ir.Attribute[] attrs)
	{
		foreach (attr; attrs) {
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
	}

	/*!
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Variable d, ir.Attribute[] attrs)
	{
		foreach (attr; attrs) {
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
				assert(attr.arguments.length == 1);
				auto constant = cast(ir.Constant) attr.arguments[0];
				if (constant is null || constant._string.length <= 2 || constant._string[0] != '\"') {
					throw makeExpected(attr, "non empty string literal argument to MangledName.");
				}
				assert(constant._string[0] == '\"');
				assert(constant._string[$-1] == '\"');
				d.mangledName = constant._string[1..$-1];
				break;
			default:
				// Warn?
			}
		}
	}

	/*!
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Aggregate s, ir.Attribute[] attrs)
	{
		foreach (attr; attrs) {
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
					throw makeBadAbstract(s, attr);
				}
				c.isAbstract = true;
				break;
			case Final:
				auto c = cast(ir.Class) s;
				if (c is null) {
					throw makeBadFinal(s, attr);
				}
				c.isFinal = true;
				break;
			default:
				// Warn?
			}
		}
	}

	/*!
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir._Interface i, ir.Attribute[] attrs)
	{
		foreach (attr; attrs) {
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
	}

	/*!
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Enum e, ir.Attribute[] attrs)
	{
		foreach (attr; attrs) {
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
	}

	/*!
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Alias a, ir.Attribute[] attrs)
	{
		foreach (attr; attrs) {
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
	}

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
			throw panic(node, "invalid attribute stack layout");
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
			throw panic(attr, "invalid attribute stack layout");
		}
		mStack = mStack[0 .. $-1];
	}

	void attrPushDown()
	{
		mCtx[$-1].stack ~= mStack;
	}

	ir.Node[] attrManip(ir.Attribute attr)
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
			return null;
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
			version (Volt) {
				return manipNodes(attr.members.nodes, nodeManipDg);
			} else {
				return manipNodes(attr.members.nodes, &nodeManipDg);
			}
		} else {
			return null;
		}
	}

	bool nodeManipDg(ir.Node node, out ir.Node[] ret)
	{
		switch (node.nodeType) with (ir.NodeType) {
		case Attribute:
			auto attr = cast(ir.Attribute)node;
			ret = attrManip(attr);
			return true;
		default:
			accept(node, this);
			return false;
		}
	}


public:
	/*
	 * Pass.
	 */
	override void transform(ir.Module m)
	{
		assert(mStack.length == 0);
		assert(mCtx.length == 0);
		accept(m, this);
		mStack = [];
		mCtx = [];
	}

	override void close()
	{
	}
}
