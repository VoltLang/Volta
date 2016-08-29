// Copyright © 2013-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.annotationresolver;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.token.location;

import volt.semantic.util;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.classify;


bool needsResolving(ir.Attribute a)
{
	if (a.kind != ir.Attribute.Kind.Annotation) {
		return false;
	}
	if (a.annotation !is null) {
		return false;
	}
	return true;
}

void actualizeAnnotation(LanguagePass lp, ir.Annotation ua)
{
	checkAnnotation(lp, ua);
	fillInAnnotationLayoutClass(lp, ua);
	ua.isActualized = true;
}

void checkAnnotation(LanguagePass lp, ir.Annotation ua)
{
	foreach (field; ua.fields) {
		lp.resolve(ua.myScope, field);

		if (!acceptableForAnnotation(lp, ua.myScope, field.type)) {
			throw makeExpected(field, "@interface suitable type");
		}
	}
}

/**
 * Generate the layout class for a given Annotation,
 * if one has not been previously generated.
 */
void fillInAnnotationLayoutClass(LanguagePass lp, ir.Annotation ua)
{
	auto _class = new ir.Class();
	_class.location = ua.location;
	_class.name = ua.name;
	_class.myScope = new ir.Scope(ua.myScope, _class, _class.name, ua.myScope.nestedDepth);
	_class.members = new ir.TopLevelBlock();
	_class.members.location = ua.location;
	ua.mangledName = mangle(ua);
	_class.mangledName = ua.mangledName;
	_class.parentClass = lp.objAttribute;
	_class.parent = buildQualifiedName(ua.location, ["object", "Attribute"]);

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
 * This does basic validation for on Annotation usage,
 * it does not check the argument types, this is left up
 * up to the extyper which calls this function.
 */
void basicValidateAnnotation(LanguagePass lp, ir.Scope current, ir.Attribute a)
{
	assert(a.kind == ir.Attribute.Kind.Annotation);

	auto store = lookup(lp, current, a.annotationName);
	if (store is null) {
		throw makeFailedLookup(a, a.annotationName.toString());
	}

	auto ua = cast(ir.Annotation) store.node;
	if (ua is null) {
		throw makeFailedLookup(a, a.annotationName.toString());
	}

	lp.actualize(ua);

	if (a.arguments.length > ua.fields.length) {
		throw makeWrongNumberOfArguments(a, a.arguments.length, ua.fields.length);
	}

	// Note this function does not check if the arguments are correct,
	// thats up to the extyper to do, which calls this function.

	a.annotation = ua;
}
