// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.declgatherer;

import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.semantic.lookup;

/**
 * Poplate the scops with Variables, Alias and Functions.
 *
 * @ingroup passes passLang
 */
class DeclarationGatherer : ScopeManager, Pass
{
public:
	override void transform(ir.Module m)
	{
		if (m.gathered) {
			return;
		}
		accept(m, this);
		m.gathered = true;
	}

	override void close()
	{
	}

	override Status enter(ir.Variable d)
	{
		assert(current !is null);
		current.addValue(d, d.name);
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		assert(current !is null);
		current.addType(a.type, a.name);
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		import std.stdio, std.conv;
		if (current.node !is null) {
			if (fn.kind == ir.Function.Kind.Function &&
				(current.node.nodeType == ir.NodeType.Struct || current.node.nodeType == ir.NodeType.Class)) {
				fn.kind = ir.Function.Kind.Member;
			}
		}
		super.enter(fn);
		return Continue;
	}
		
	override Status enter(ir.Class _class)
	{
		super.enter(_class);
		if (_class.parent is null) {
			return Continue;
		} else {
			assert(_class.parent.identifiers.length == 1);
			/// @todo Correct look up.
			auto store = _class.myScope.lookup(_class.parent.identifiers[0].value);
			if (store is null) {
				throw new CompilerError(_class.parent.location, format("unidentified identifier '%s'.", _class.parent));
			}
			if (store.node is null || store.node.nodeType != ir.NodeType.Class) {
				throw new CompilerError(_class.parent.location, format("'%s' is not a class.", _class.parent));
			}
			auto asClass = cast(ir.Class) store.node;
			assert(asClass !is null);
			_class.parentClass = asClass;
		}
		return Continue;
	}
}
