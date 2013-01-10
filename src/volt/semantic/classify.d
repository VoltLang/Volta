// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classify;

import std.range : array, retro;
import std.conv : to;
import std.stdio : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.token.location;
import volt.semantic.lookup;


int size(ir.PrimitiveType.Kind kind)
{
	final switch (kind) with (ir.PrimitiveType.Kind) {
	case Void: return 1;
	case Bool: return 1;
	case Char: return 1;
	case Byte: return 1;
	case Ubyte: return 1;
	case Short: return 2;
	case Ushort: return 2;
	case Int: return 4;
	case Uint: return 4;
	case Long: return 8;
	case Ulong: return 8;
	case Float: return 4;
	case Double: return 8;
	case Real: return 8;
	}
}

int size(Location location, ir.Node node)
{
	switch (node.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto asPrim = cast(ir.PrimitiveType) node;
		assert(asPrim !is null);
		return size(asPrim.type);
	case Struct:
		auto asStruct = cast(ir.Struct) node;
		assert(asStruct !is null);
		return structSize(location, asStruct);
	case Variable:
		auto asVariable = cast(ir.Variable) node;
		assert(asVariable !is null);
		return size(location, asVariable.type);
	case PointerType, FunctionType:
		return 4;  /// @todo Aieeeeeeeeeeeeeeeeeeeeeeeeeeee!!!
	case ArrayType:
		return 8;  /// @todo See above.
	case TypeReference:
		auto asTR = cast(ir.TypeReference) node;
		assert(asTR !is null);
		return size(location, asTR.type);
	default:
		throw new CompilerError(location, format("couldn't retrieve size of element: %s", to!string(node.nodeType)));
	}
}

/// Returns the size of a given Struct, in bytes.
int structSize(Location location, ir.Struct s)
{
	int sizeAccumulator;
	foreach (node; s.members.nodes) {
		// If it's not a Variable, it shouldn't take up space.
		if (node.nodeType != ir.NodeType.Variable) {
			continue;
		}

		sizeAccumulator += size(location, node);
	}
	return sizeAccumulator;
}

bool isIntegral(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
		case Byte:
		case Ubyte:
		case Short:
		case Ushort:
		case Int:
		case Uint:
		case Long:
		case Ulong:
			return true;
		default:
			return false;
	}
}

bool isUnsigned(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Void:
	case Byte:
	case Short:
	case Int:
	case Long:
	case Float:
	case Double:
	case Real:
		return false;
	default:
		return true;
	}
}

bool isOkayForPointerArithmetic(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Byte:
	case Ubyte:
	case Short:
	case Ushort:
	case Int:
	case Uint:
	case Long:
	case Ulong:
		return true;
	default:
		return false;
	}
}

bool isComparison(ir.BinOp.Type t)
{
	switch (t) with (ir.BinOp.Type) {
	case OrOr, AndAnd, Equal, NotEqual, Is, NotIs, Less, LessEqual, Greater, GreaterEqual:
		return true;
	default:
		return false;
	}
}

bool isValidPointerArithmeticOperation(ir.BinOp.Type t)
{
	switch (t) with (ir.BinOp.Type) {
	case Add, Sub:
		return true;
	default:
		return false;
	}
}

bool fitsInPrimitive(ir.PrimitiveType t, ir.Exp e)
{
	if (e.nodeType != ir.NodeType.Constant) {
		return false;
	}
	auto asConstant = cast(ir.Constant) e;
	assert(asConstant !is null);

	if (isIntegral(t.type)) {
		long l;
		try {
			l = to!long(asConstant.value);
		} catch (Throwable t) {
			return false;
		}
		switch (t.type) with (ir.PrimitiveType.Kind) {
		case Ubyte:
			return l >= ubyte.min && l <= ubyte.max;
		case Byte:
			return l >= byte.min && l <= byte.max;
		case Ushort:
			return l >= ushort.min && l <= ushort.max;
		case Short:
			return l >= short.min && l <= short.max;
		case Uint:
			return l >= uint.min && l <= uint.max;
		case Int:
			return l >= int.min && l <= int.max;
		case Long:
			return true;
		case Ulong:
			return false;
		case Float:
			return l >= float.min && l <= float.max;
		case Double:
			return l >= double.min && l <= double.max;
		default:
			return false;
		}
	} else {
		return false;
	}
}

/**
 * Determines whether the two given types are the same.
 *
 * Not similar. Not implicitly convertable. The _same_ type.
 * Returns: true if they're the same, false otherwise.
 */
bool typesEqual(ir.Type a, ir.Type b)
{
	if (a.nodeType == ir.NodeType.PrimitiveType &&
	    b.nodeType == ir.NodeType.PrimitiveType) {
		auto ap = cast(ir.PrimitiveType) a;
		auto bp = cast(ir.PrimitiveType) b;
		assert(ap !is null && bp !is null);
		return ap.type == bp.type;
	} else if (a.nodeType == ir.NodeType.PointerType &&
	           b.nodeType == ir.NodeType.PointerType) {
		auto ap = cast(ir.PointerType) a;
		auto bp = cast(ir.PointerType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.base, bp.base);
	} else if (a.nodeType == ir.NodeType.ArrayType &&
	           b.nodeType == ir.NodeType.ArrayType) {
		auto ap = cast(ir.ArrayType) a;
		auto bp = cast(ir.ArrayType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.base, ap.base);
	} else if (a.nodeType == ir.NodeType.TypeReference &&
	           b.nodeType == ir.NodeType.TypeReference) {
		auto ap = cast(ir.TypeReference) a;
		auto bp = cast(ir.TypeReference) b;
		assert(ap !is null && bp !is null);
		return ap.names == bp.names;
	} else if ((a.nodeType == ir.NodeType.FunctionType &&
	            b.nodeType == ir.NodeType.FunctionType) ||
		   (a.nodeType == ir.NodeType.DelegateType &&
	            b.nodeType == ir.NodeType.DelegateType)) {
		auto ap = cast(ir.CallableType) a;
		auto bp = cast(ir.CallableType) b;
		assert(ap !is null && bp !is null);

		if (ap.params.length != bp.params.length)
			return false;
		auto ret = typesEqual(ap.ret, bp.ret);
		if (!ret)
			return false;
		for (int i; i < ap.params.length; i++)
			if (!typesEqual(ap.params[i].type, bp.params[i].type))
				return false;
		return true;
	} else {
		return a is b;
	}
}

/// Retrieves the types of Variables in _struct, in the order they appear.
ir.Type[] getStructFieldTypes(ir.Struct _struct)
{
	ir.Type[] types;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asVar = cast(ir.Variable) node;
		if (asVar is null) {
			continue;
		}
		types ~= asVar.type;
		assert(types[$-1] !is null);
	}

	return types;
}

/**
 * Lookup something with a scope in another scope.
 * Params:
 *   _scope   = the scope to look in.
 *   name     = the name to look up in _scope.
 *   location = the location to point an error message at.
 *   member   = what you want to look up in the returned scope, for error message purposes.
 * Returns: the Scope found in _scope.
 * Throws: CompilerError if a Scope bearing thing couldn't be found in _scope.
 *
 * @todo refactor to lookup
 */
ir.Scope scopeLookup(ir.Scope _scope, string name, Location location, string member)
{
	string emsg = format("expected aggregate with member '%s'.", member);

	auto current = _scope;
	while (current !is null) {
		auto store = current.lookupOnlyThisScope(name, location);
		if (store is null) {
			current = current.parent;
			continue;
		}
		if (store.s !is null) {
			return store.s;
		}
		if (store.kind != ir.Store.Kind.Type) {
			// !!! this will need to handle more cases some day.
			throw new CompilerError(location, emsg);
		}
		switch (store.node.nodeType) with (ir.NodeType) {
		case Struct:
			auto asStruct = cast(ir.Struct) store.node;
			assert(asStruct !is null);
			return asStruct.myScope;
		case Class:
			auto asClass = cast(ir.Class) store.node;
			assert(asClass !is null);
			return asClass.myScope;
		case Interface:
			auto asInterface = cast(ir._Interface) store.node;
			assert(asInterface !is null);
			return asInterface.myScope;
		default:
			throw new CompilerError(location, emsg);
		}
	}
	throw new CompilerError(location, emsg);
}

ir.Function[] getStructFunctions(ir.Struct _struct)
{
	ir.Function[] functions;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asFunction = cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}
		functions ~= asFunction;
	}

	return functions;
}

ir.Function[] getClassFunctions(ir.Class _class)
{
	ir.Function[] functions;

	if (_class.members !is null) foreach (node; _class.members.nodes) {
		auto asFunction = cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}
		functions ~= asFunction;
	}

	return functions;
}

/// Returns: true if child is a child of parent.
bool inheritsFrom(ir.Class child, ir.Class parent)
{
	auto currentClass = child;
	while (currentClass !is null) {
		if (currentClass is parent) {
			return true;
		}
		currentClass = currentClass.parentClass;
	}
	return false;
}

string[] getParentScopeNames(ir.Scope _scope)
{
	string[] backwardsNames;
	ir.Scope currentScope = _scope;
	while (currentScope !is null) {
		backwardsNames ~= currentScope.name;
		currentScope = currentScope.parent;
	}
	return array(retro(backwardsNames));
}
