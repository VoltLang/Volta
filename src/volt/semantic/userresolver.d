// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.userresolver;

import std.array : array;
import std.algorithm : sort;
import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.semantic.lookup;
import volt.semantic.classify;

/// @todo refactor to lookup
ir.Type typeLookup(ir.Scope _scope, string name, Location location)
{
	auto store = _scope.lookup(name, location);
	if (store is null) {
		throw new CompilerError(location, format("undefined identifier '%s'.", name));
	}
	if (store.kind != ir.Store.Kind.Type) {
		throw new CompilerError(location, format("%s used as type.", name));
	}
	auto asType = cast(ir.Type) store.node;
	assert(asType !is null);
	return asType;
}

/**
 * Resolves all @link volt.ir.type.TypeReference TypeReferences@endlink.
 *
 * @ingroup passes passLang
 */
class UserResolver : ScopeManager, Pass
{
public:
	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.StorageType storageType)
	{
		// Get a list of storage kinds for all consecutive storage types.
		ir.StorageType.Kind[] storageChain;
		ir.StorageType current = storageType;
		ir.Type endOfChain;
		do {
			storageChain ~= current.type;
			if (current.base.nodeType != ir.NodeType.StorageType) {
				endOfChain = current.base;
				break;
			}
			current = cast(ir.StorageType) current.base;
			assert(current !is null);
		} while (true);
		assert(endOfChain !is null);

		if (storageChain.length == 1) {
			return Continue;
		}

		// Get a set of storage kinds, following overriding rules (see StorageType docs).
		bool[ir.StorageType.Kind] seenStorage;
		foreach (kind; storageChain) {
			if (kind == ir.StorageType.Kind.Immutable) {
				seenStorage.remove(ir.StorageType.Kind.Inout);
				seenStorage.remove(ir.StorageType.Kind.Const);
				seenStorage[kind] = true;
				continue;
			} else if (kind == ir.StorageType.Kind.Inout) {
				if (auto p = ir.StorageType.Kind.Immutable in seenStorage) {
					continue;
				}
				seenStorage.remove(ir.StorageType.Kind.Const);
				seenStorage[kind] = true;
				continue;
			} else if (kind == ir.StorageType.Kind.Const) {
				if (auto p = ir.StorageType.Kind.Immutable in seenStorage) {
					continue;
				} else if (auto p = ir.StorageType.Kind.Inout in seenStorage) {
					continue;
				}
			}
			seenStorage[kind] = true;
		}

		// If there's more than one storage type, then remove an auto if it exists.
		if (seenStorage.keys.length > 1) {
			seenStorage.remove(ir.StorageType.Kind.Auto);
		}

		bool storageComp(ir.StorageType.Kind a, ir.StorageType.Kind b)
		{
			if (a == ir.StorageType.Kind.Scope) {
				return true;
			} else {
				return false;
			}
		}

		// Sort the resulting set of storage kinds to ensure scope comes first.
		ir.StorageType.Kind[] outChain = sort!storageComp(seenStorage.keys).array();

		// Given the sorted kinds, recreate a chain of storage types.
		current = storageType;
		foreach (i, type; outChain) {
			current.type = type;
			if (i < outChain.length - 1) {
				auto newStorage = new ir.StorageType();
				newStorage.location = current.location;
				current.base = newStorage;
				current = newStorage;
			}
		}
		assert(current.base is null);
		current.base = endOfChain;

		// Skip over all of those storage types.
		accept(endOfChain, this);
		return ContinueParent;
	}

	override Status visit(ir.TypeReference u)
	{
		ir.Scope lookupScope = current;
		ir.Type theType;
		foreach (i, name; u.names) {
			if (i == u.names.length - 1) {
				theType = typeLookup(lookupScope, name, u.location);
				break;
			}
			lookupScope = scopeLookup(lookupScope, name, u.location, u.names[i+1]);
		}
		assert(theType !is null);

		u.type = theType;

		return Continue;
	}
}
