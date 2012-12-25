// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.declgatherer;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

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
}
