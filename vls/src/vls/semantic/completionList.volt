// Code for creating completion lists.
module vls.semantic.completionList;

import core = core.rt.format;
import watt = [watt.text.sink, watt.path];
import json = watt.json;

import ir = volta.ir;
import volta = volta.util.stack;

import lsp = vls.lsp;
import printing = vls.util.printing;

struct I32Stack = mixin volta.Stack!i32;

/*!
 * Structure that generates a completion list
 * from stores and names.
 */
struct CompletionList
{
	/*!
	 * Add an item corresponding to the `store`,
	 * associated with `name`.
	 */
	fn add(name: string, store: ir.Store)
	{
		item: CompletionItem;
		item.name = name;
		item.kind = getItemKind(store);
		item.doc = cast(string)json.escapeString(new "${getDocumentationTitle(store)}\n\n${store.node.docComment}");
		mItemStack.push(item);
	}

	/*!
	 * Add a name with an explicit kind.
	 */
	fn add(name: string, kind: i32, documentation: const(char)[] = null)
	{
		item: CompletionItem;
		item.name = name;
		item.kind = kind;
		if (documentation !is null) {
			item.doc = cast(string)json.escapeString(documentation);
		}
		mItemStack.push(item);
	}

	/*!
	 * Add all symbols in a given scope.
	 */
	fn add(_scope: ir.Scope)
	{
		foreach (name, store; _scope.symbols) {
			add(name, store);
		}
	}

	/*!
	 * Exclude any items of the given item kind
	 * (COMPLETION_BLAH) from being included in
	 * the output of `jsonArray`.
	 */
	fn exclude(kind: i32) {
		mExclusionStack.push(kind);
	}

	/*!
	 * Generate a completed list, approriate as a result parameter.
	 */
	fn jsonArray() string
	{
		exclusions := mExclusionStack.borrowUnsafe();
		ss: watt.StringSink;
		items := mItemStack.borrowUnsafe();
		ss.sink("[");
		firstElement := true;
		foreach (i, item; items) {
			skip := false;
			foreach (exclusion; exclusions) {
				if (item.kind == exclusion) {
					skip = true;
					break;
				}
			}
			if (skip) {
				continue;
			}
			if (!firstElement) {
				ss.sink(`, `);
			}
			firstElement = false;
			ss.sink(`{"label":"`);
			ss.sink(item.name);
			ss.sink(`","kind":`);
			core.vrt_format_i64(ss.sink, item.kind);
			ss.sink(`,"documentation":{"kind":"markdown","value":"`);
			ss.sink(item.doc);
			ss.sink(`"}}`);
		}
		ss.sink("]");
		return ss.toString();
	}

	private mItemStack: ItemStack;
	private mExclusionStack: I32Stack;
}

private:

struct ItemStack = mixin volta.Stack!CompletionItem;

struct CompletionItem
{
	name: string;
	kind: i32;
	doc: string;
}

fn getDocumentationTitle(store: ir.Store) const(char)[]
{
	storeString := printing.storeString(store);
	return getDocumentationTitle(ref store.node.loc, storeString);
}

fn getDocumentationTitle(ref loc: ir.Location, str: const(char)[]) const(char)[]
{
	ss: watt.StringSink;
	ss.sink("`");
	ss.sink(watt.baseName(loc.filename, ""));
	ss.sink(`:`);
	core.vrt_format_u64(ss.sink, loc.line);
	ss.sink(`:`);
	core.vrt_format_u64(ss.sink, loc.column);
	ss.sink("`");
	if (str !is null) {
		ss.sink("\n\n`");
		ss.sink(str);
		ss.sink("`");
	}
	return ss.toString();
}

fn getItemKind(store: ir.Store) i32
{
	switch (store.kind) with (ir.Store.Kind) {
	case Scope, MultiScope:
		return lsp.COMPLETION_MODULE;
	default:
		break;
	}
	switch (store.node.nodeType) with (ir.NodeType) {
	case Function: return lsp.COMPLETION_FUNCTION;
	case FunctionParam: return lsp.COMPLETION_VARIABLE;
	case Variable:
		var := store.node.toVariableFast();
		if (var.storage == ir.Variable.Storage.Field) {
			return lsp.COMPLETION_FIELD;
		} else {
			return lsp.COMPLETION_VARIABLE;
		}
	default: return lsp.COMPLETION_TEXT;
	}
}