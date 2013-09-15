// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.userattrresolver;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.errors;

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

void actualizeUserAttribute(LanguagePass lp, ir.UserAttribute ua)
{
	checkUserAttribute(lp, ua);
	fillInUserAttributeLayoutClass(lp, ua);
	ua.isActualized = true;
}

void checkUserAttribute(LanguagePass lp, ir.UserAttribute ua)
{
	foreach (field; ua.fields) {
		lp.resolve(ua.myScope, field);

		if (!acceptableForUserAttribute(lp, ua.myScope, field.type)) {
			throw makeExpected(field, "@interface suitable type");
		}
	}
}

/**
 * Generate the layout class for a given UserAttribute,
 * if one has not been previously generated.
 */
void fillInUserAttributeLayoutClass(LanguagePass lp, ir.UserAttribute ua)
{
	auto _class = new ir.Class();
	_class.location = ua.location;
	_class.name = ua.name;
	_class.myScope = new ir.Scope(ua.myScope, _class, _class.name);
	_class.members = new ir.TopLevelBlock();
	_class.members.location = ua.location;
	ua.mangledName = mangle(ua);
	_class.mangledName = ua.mangledName;
	_class.parentClass = lp.attributeClass;
	_class.parent = buildQualifiedName(ua.location, ["object", "Attribute"]);

	auto fn = buildFunction(ua.location, _class.members, _class.myScope, "__ctor", true);
	fn.kind = ir.Function.Kind.Constructor;
	buildReturnStat(ua.location, fn._body);
	_class.userConstructors ~= fn;

	foreach (field; ua.fields) {
		auto v = copyVariableSmart(ua.location, field);
		v.storage = ir.Variable.Storage.Field;

		_class.members.nodes ~= v;
		_class.myScope.addValue(v, v.name);
	}
	ua.layoutClass = _class;

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
		throw makeFailedLookup(a, a.userAttributeName.toString());
	}

	auto ua = cast(ir.UserAttribute) store.node;
	if (ua is null) {
		throw makeFailedLookup(a, a.userAttributeName.toString());
	}

	lp.actualize(ua);

	if (a.arguments.length > ua.fields.length) {
		throw makeWrongNumberOfArguments(a, a.arguments.length, ua.fields.length);
	}

	// Note this function does not check if the arguments are correct,
	// thats up to the extyper to do, which calls this function.

	a.userAttribute = ua;
}
