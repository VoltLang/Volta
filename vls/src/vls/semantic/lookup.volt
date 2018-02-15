/*!
 * Stores, scopes, and the retrieval thereof.
 */
module vls.semantic.lookup;

import watt = watt.io;
import ir = volta.ir;

import vls.util.simpleCache;
import vls.semantic.actualiseClass;

//! If `node` is an `Aggregate`, return `true`. Otherwise `aggregate` is null and return `false`.
fn getAggregate(node: ir.Node, out aggregate: ir.Aggregate) bool
{
	aggregate = cast(ir.Aggregate)node;
	return aggregate !is null;
}

fn lookupInScopeChain(ref cache: SimpleImportCache, _scope: ir.Scope, name: string, out modscope: ir.Scope) ir.Store
{
	current := _scope;
	while (current !is null) {
		store := current.getStore(name);
		if (store !is null) {
			return store;
		}
		foreach (mscope; current.multibindScopes) {
			store = mscope.getStore(name);
			if (store !is null) {
				return store;
			}
		}
		if (current.node !is null) {
			_class := current.node.toClassChecked();
			if (_class !is null) {
				actualise(ref cache, _class);
				store = lookupClassChain(ref cache, _class, name);
				if (store !is null) {
					return store;
				}
			}
		}
		if (current.parent is null) {
			modscope = current;
		}
		current = current.parent;
	}
	return null;
}

fn lookupClassChain(ref cache: SimpleImportCache, _class: ir.Class, name: string) ir.Store
{
	current := _class;
	while (current !is null) {
		store := current.myScope.getStore(name);
		if (store !is null) {
			return store;
		}
		current = current.parentClass;
	}
	return null;
}

fn lookup(ref cache: SimpleImportCache, context: ir.Scope, name: ir.QualifiedName) ir.Store
{
	store: ir.Store;
	foreach (part; name.identifiers) {
		if (store is null) {
			store = lookup(ref cache, context, part.value);
			if (store is null) {
				return null;
			}
		} else {
			_scope := getScopeFromStore(ref cache, store, context);
			if (_scope is null) {
				return null;
			}
			store = _scope.getStore(part.value);
			if (store is null) {
				foreach (mscope; _scope.multibindScopes) {
					store = mscope.getStore(part.value);
					if (store !is null) {
						break;
					}
				}
			}
			if (store is null) {
				// Check public imports.
				foreach (i, mod; _scope.importedModules) {
					if (_scope.importedAccess[i] == ir.Access.Public) {
						// TODO: lookup in here, share import cache.
						store = mod.myScope.getStore(part.value);
					}
					if (store !is null) {
						// TODO: Handle multiple matches etc.
						break;
					}
				}
			}
		}
	}
	return store;
}

fn lookup(ref cache: SimpleImportCache, context: ir.Scope, name: string) ir.Store
{
	modscope: ir.Scope;
	store := lookupInScopeChain(ref cache, context, name, out modscope);
	if (store !is null) {
		return store;
	}
	foreach (importedMod; modscope.importedModules) {
		if (cache.hasResult(importedMod.name.toString())) {
			continue;
		}
		cache.setResult(importedMod.name.toString(), importedMod);
		if (importedMod.myScope is modscope) {
			continue;
		}
		store = lookup(ref cache, importedMod.myScope, name);
		if (store !is null) {
			return store;
		}
	}
	return null;
}

fn getScopeFromStore(ref cache: SimpleImportCache, store: ir.Store, context: ir.Scope) ir.Scope
{
	if (store.scopes.length > 1) {
		return new ir.Scope(store.scopes);
	}
	if (store.kind == ir.Store.Kind.Scope) {
		return store.myScope;
	}
	vtype := getTypeFromVariableLike(ref cache, store, context);
	if (vtype is null) {
		return null;
	}

	ptr := vtype.toPointerTypeChecked();
	if (ptr !is null && ptr.base !is null) {
		/* This doesn't need to support pointers to pointers,
		 * as Volt only dereferences one level automatically.
		 */
		vtype = ptr.base;
	}

	tr := vtype.toTypeReferenceChecked();
	if (tr is null) {
		return null;
	}
	tlstore := lookup(ref cache, context, tr.id);
	if (tlstore is null) {
		return null;
	}

	node := resolveAlias(tlstore.node, ref cache, context);

	agg: ir.Aggregate;
	if (getAggregate(node, out agg)) {
		return agg.myScope;
	}
	return null;
}

/*!
 * If `node` is an alias, resolve it. Otherwise `node` is returned as is.
 */
fn resolveAlias(node: ir.Node, ref cache: SimpleImportCache, context: ir.Scope) ir.Node
{
	if (node is null) {
		return null;
	}
	currentNode := node;
	while (currentNode.nodeType == ir.NodeType.Alias) {
		_alias := currentNode.toAliasFast();
		if (_alias.type !is null) {
			return _alias.type;
		}
		if (_alias.id is null) {
			return node;
		}
		store := lookup(ref cache, context, _alias.id);
		if (store is null) {
			return node;
		}
		currentNode = store.node;
	}
	return currentNode;
}

//! If `store` is a variable or param, get the type.
fn getTypeFromVariableLike(ref cache: SimpleImportCache, store: ir.Store, context: ir.Scope) ir.Type
{
	if (store is null) {
		return null;
	}
	type: ir.Type;
	assign: ir.Exp;
	var := store.node.toVariableChecked();
	if (var !is null) {
		type = var.type;
		assign = var.assign;
	}
	fp := store.node.toFunctionParamChecked();
	if (fp !is null) {
		type = fp.type;
	}
	if (type !is null && assign !is null && type.nodeType == ir.NodeType.AutoType) {
		switch (assign.nodeType) with (ir.NodeType) {
		case Unary:
			un := assign.toUnaryFast();
			if (un.type !is null) {
				type = un.type;
			}
			break;
		case Postfix:
			pfx := assign.toPostfixFast();
			if (pfx.op != ir.Postfix.Op.Call) {
				goto default;
			}
			_store := getStoreFromFragment(ref cache, pfx.child, context, context);
			if (_store !is null && _store.node.nodeType == ir.NodeType.Function) {
				func := _store.node.toFunctionFast();
				type = func.type.ret;
			}
			break;
		default:
			break;
		}
	}
	return type;
}

fn getStoreFromFragment(ref cache: SimpleImportCache, fragment: ir.Exp, context: ir.Scope, parentContext: ir.Scope) ir.Store
{
	switch (fragment.nodeType) with (ir.NodeType) {
	case IdentifierExp:
		ie := fragment.toIdentifierExpFast();
		store := lookup(ref cache, context, ie.value);
		if (store is null && parentContext !is null) {
			store = lookup(ref cache, parentContext, ie.value);
		}
		return store;
	case Postfix:
		postfix := fragment.toPostfixFast();
		if (postfix.identifier is null) {
			return null;
		}
		if (postfix.child is null) {
			return null;
		}
		store := getStoreFromFragment(ref cache, postfix.child, context, parentContext);
		if (store is null) {
			return null;
		}
		childContext := getScopeFromStore(ref cache, store, context);
		if (childContext is null) {
			return null;
		}
		store = lookup(ref cache, childContext, postfix.identifier.value);
		return store;
	default:
		return null;
	}
}
