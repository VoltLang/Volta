/*#D*/
// Copyright 2017, Bernard Helyer.
// Copyright 2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.ir.templates;

import volta.ir.base;
import volta.ir.context;
import volta.ir.type;
import volta.ir.toplevel;
import volta.ir.declaration;
import volta.ir.expression;

import volta.util.dup;


enum TemplateKind
{
	Struct,
	Class,
	Union,
	Interface,
	Function
}

/*!
 * Creates a concrete instance of a template.
 *
 * Example:
 *   struct Foo = Bar!i32
 *   fn Foo = Bar!(size_t*, i16)
 *
 * @ingroup irNode irTemplate
 */
class TemplateInstance : Node
{
public:
	TemplateKind kind;

	QualifiedName definitionName; // struct Foo = <Bar>!i32;
	string instanceName; // struct <Foo> = Bar!i32;

	bool explicitMixin;
	bool isResolved;  // Has this instance been resolved.
	Node[] arguments;  // Either a Type or an Exp.
	string[] names;  // Set by the lifter.
	Scope myScope;  // Set by gatherer.
	Scope oldParent;  // Used by the extyper to evaluate the instance in the right place.

	Struct _struct;
	Function _function;
	Class _class;
	Union _union;
	_Interface _interface;

public:
	this()
	{
		super(NodeType.TemplateInstance);
	}

	this(TemplateInstance old)
	{
		super(NodeType.TemplateInstance, old);
		this.kind = old.kind;
		this.instanceName = old.instanceName;
		this.definitionName = old.definitionName;
		this.arguments = old.arguments.dup();
		this.names = old.names.dup();
		this.explicitMixin = old.explicitMixin;
		this.myScope = old.myScope;
		this._struct = old._struct;
		this._function = old._function;
		this._class = old._class;
		this._union = old._union;
		this._interface = old._interface;
		this.oldParent = old.oldParent;
	}
}

class TemplateDefinition : Node
{
public:
	struct Parameter
	{
		Type type;  // Optional, only for value parameters.
		string name;
	}

public:
	TemplateKind kind;
	string name;
	Parameter[] parameters;
	TypeReference[] typeReferences;  //!< Filled in by the gatherer.
	Scope myScope;  //!< Filled in by the gatherer.
	/*!
	 * Only one of these fields will be non-null, depending on kind.
	 * @{
	 */
	Struct _struct;
	Union _union;
	_Interface _interface;
	Class _class;
	Function _function;
	//! @}

public:
	this()
	{
		super(NodeType.TemplateDefinition);
	}

	this(TemplateDefinition old)
	{
		super(NodeType.TemplateDefinition, old);
		this.kind = old.kind;
		this.name = old.name;
		this.parameters = old.parameters.dup();
		this._struct = old._struct;
		this._union = old._union;
		this._interface = old._interface;
		this._class = old._class;
		this._function = old._function;
	}
}
