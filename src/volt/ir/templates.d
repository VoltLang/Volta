// Copyright © 2017, Bernard Helyer.  All rights reserved.
// Copyright © 2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.templates;

import volt.ir.base;
import volt.ir.context;
import volt.ir.type;
import volt.ir.toplevel;
import volt.ir.declaration;


enum TemplateKind
{
	Struct,
	Class,
	Union,
	Interface,
	Function
}

/**
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
	string name;
	Type[] typeArguments;
	bool explicitMixin;
	string[] typeNames;  // Set by the lifter.

public:
	this()
	{
		super(NodeType.TemplateInstance);
	}

	this(TemplateInstance old)
	{
		super(NodeType.TemplateInstance, old);
		this.kind = old.kind;
		this.name = old.name;
		version (Volt) {
			this.typeArguments = new old.typeArguments[0 .. $];
			this.typeNames = new old.typeNames[0 .. $];
		} else {
			this.typeArguments = old.typeArguments.dup;
			this.typeNames = old.typeNames.dup;
		}
	}
}

class TemplateDefinition : Node
{
public:
	TemplateKind kind;
	string name;
	string[] typeParameters;
	TypeReference[] typeReferences;  //< Filled in by the gatherer.
	/**
	 * Only one of these fields will be non-null, depending on kind.
	 * @{
	 */
	Struct _struct;
	Union _union;
	_Interface _interface;
	Class _class;
	Function _function;
	/// @}

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
		version (Volt) {
			this.typeParameters = new old.typeParameters[0 .. $];
		} else {
			this.typeParameters = old.typeParameters.dup;
		}
		this._struct = old._struct;
		this._union = old._union;
		this._interface = old._interface;
		this._class = old._class;
		this._function = old._function;
	}
}
