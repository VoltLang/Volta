// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.declgatherer;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.scopemanager;


class DeclarationGatherer : ScopeManager, Pass
{
public:
	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Variable d)
	{
		current.addValue(d, d.name);
		return Continue;
	}
}
