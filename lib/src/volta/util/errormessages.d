/*#D*/
// Copyright © 2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
//! Code for generating error message strings.
module volta.util.errormessages;

import watt.text.format : format;
import ir = volta.ir;
import volta.ir.location;

string badAbstractMsg()
{
	return "only classes and functions may be marked as abstract.";
}

string badFinalMsg()
{
	return "only classes, functions, and switch statmenets may be marked as final.";
}

string shadowsDeclarationMsg(ir.Node node)
{
	return format("shadows declaration at %s.", node.loc.toString());
}

string abstractHasToBeMemberMsg(ir.Function func)
{
	return format("abstract functions like '%s' must be a member of an abstract class.", func.name);
}

string anonymousAggregateAtTopLevelMsg()
{
	return "anonymous struct or union not inside aggregate.";
}

string abstractBodyNotEmptyMsg(ir.Function func)
{
	return format("abstract functions like '%s' may not have an implementation.", func.name);
}

string nonTopLevelImportMsg()
{
	return "imports must occur in the top scope.";
}

string cannotImportMsg(string name)
{
	return format("can't find module '%s'.", name);
}

string cannotImportAnonymousMsg(string name)
{
	return format("can't import anonymous module '%s'.", name);
}

string redefinesSymbolMsg(string name, ref in Location loc)
{
	return format("redefines symbol '%s', defined @ %s", name, loc.toString());
}

string overloadFunctionAccessMismatchMsg(ir.Access importAccess, ir.Alias a, ir.Function b)
{
	return format("alias '%s' access level ('%s') does not match '%s' ('%s') @ %s.",
	a.name, ir.accessToString(importAccess), b.name, ir.accessToString(b.access), b.loc.toString());
}

string scopeOutsideFunctionMsg()
{
	return "scopes must be inside a function.";
}
