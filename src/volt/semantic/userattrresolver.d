// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.userattrresolver;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.exceptions;

import volt.token.location;

import volt.semantic.classify;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.util;


bool needsResolving(ir.Attribute a)
{
	if (a.kind != ir.Attribute.Kind.UserAttribute) {
		return false;
	}
	if (a.userAttribute !is null) {
		return false;
	}
	return true;
}

bool needsActualizing(ir.UserAttribute attr)
{
	return attr.layoutClass is null;
}

void actualizeUserAttribute(LanguagePass lp, ir.UserAttribute attr)
{
	checkUserAttribute(lp, attr);
	fillInUserAttributeLayoutClass(lp, attr);
}

void checkUserAttribute(LanguagePass lp, ir.UserAttribute attr)
{
	foreach (field; attr.fields) {
		lp.resolve(attr.myScope, field);

		if (!acceptableForUserAttribute(lp, attr.myScope, field.type)) {
			throw new CompilerError(field.location, "field type unacceptable for @interface.");
		}
	}
}

/**
 * Generate the layout class for a given UserAttribute,
 * if one has not been previously generated.
 */
void fillInUserAttributeLayoutClass(LanguagePass lp, ir.UserAttribute attr)
{
	auto _class = new ir.Class();
	_class.location = attr.location;
	_class.name = attr.name;
	_class.myScope = new ir.Scope(attr.myScope, _class, _class.name);
	_class.members = new ir.TopLevelBlock();
	_class.members.location = attr.location;
	attr.mangledName = mangle(null, attr);
	_class.mangledName = attr.mangledName;
	_class.parentClass = retrieveAttribute(lp, attr.myScope, attr.location);
	_class.parent = buildQualifiedName(attr.location, ["object", "Attribute"]);

	auto fn = buildFunction(attr.location, _class.members, _class.myScope, "__ctor", true);
	fn.kind = ir.Function.Kind.Constructor;
	buildReturnStat(attr.location, fn._body);
	_class.userConstructors ~= fn;

	foreach (field; attr.fields) {
		auto v = copyVariableSmart(attr.location, field);
		v.storage = ir.Variable.Storage.Field;

		_class.members.nodes ~= v;
		_class.myScope.addValue(v, v.name);
	}
	attr.layoutClass = _class;

	lp.actualize(_class);
}

/**
 * This does basic validation for on UserAttribute usage,
 * it does not check the argument types, this is left up
 * up to the extyper which calls this function.
 */
void basicValidateUserAttribute(LanguagePass lp, ir.Scope current, ir.Attribute a)
{
	assert(a.kind == ir.Attribute.Kind.UserAttribute);

	auto store = lookup(lp, current, a.userAttributeName);
	if (store is null) {
		throw new CompilerError(a.location, "unknown user attribute.");
	}

	auto ua = cast(ir.UserAttribute) store.node;
	if (ua is null) {
		auto emsg = format("'%s' is not a user attribute.", a.userAttributeName);
		throw new CompilerError(a.location, emsg);
	}

	lp.actualize(ua);

	if (a.arguments.length > ua.fields.length) {
		throw new CompilerError(a.location, "too many fields for @interface " ~ ua.name);
	}

	// Note this function does not check if the arguments are correct,
	// thats up to the extyper to do, which calls this function.

	a.userAttribute = ua;
}
