// Copyright 2017-2018, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module vls.semantic.symbolGathererVisitor;

import core.rt.format;

import watt.io;
import watt.text.sink;

import ir = volta.ir;

import volta.visitor.visitor;
import volta.ir.location;

import vls.lsp.constants;

struct Symbol
{
	name: string;
	loc: Location;
	type: SymbolType;
	containerName: string;

	fn jsonString(uri: string, sink: Sink)
	{
		sink(`{"name":"`);
		sink(name);
		sink(`","kind":`);
		vrt_format_i64(sink, type);
		sink(`,"location":`);
		locationToJsonString(ref loc, uri, sink);
		if (containerName.length > 0) {
			sink(`, "containerName":"`);
			sink(containerName);
			sink(`"`);
		}
		sink("}");
	}
}

fn locationToJsonString(ref loc: Location, uri: string, sink: Sink)
{
	sink(`{"uri":"`);
	sink(uri);
	sink(`","range":`);
	locationToRange(ref loc, sink);
	sink("}");
}

fn locationToRange(ref loc: Location, sink: Sink)
{
	endLoc := loc;
	endLoc.column += loc.length;
	sink(`{"start":`);
	locationToPosition(ref loc, sink);
	sink(`,"end":`);
	locationToPosition(ref loc, sink);
	sink(`}`);
}

fn locationToPosition(ref loc: Location, sink: Sink)
{
	sink(`{"line":`);
	vrt_format_u64(sink, loc.line - 1);
	sink(`,"character":`);
	vrt_format_u64(sink, loc.column);
	sink(`}`);
}

class SymbolGathererVisitor : NullVisitor
{
public:
	symbols: Symbol[];

private:
	parents: string[];

public:
	override fn enter(mod: ir.Module) Status
	{
		addSymbol(mod, mod.name.toString(), SymbolType.Module);
		return Status.Continue;
	}

	override fn enter(func: ir.Function) Status
	{
		kind: i32;
		name := func.name;
		switch (func.kind) with (ir.Function.Kind) {
		case Member:
			kind = SymbolType.Method;
			break;
		case Constructor:
			kind = SymbolType.Constructor;
			name = "this";
			break;
		case Destructor:
			name = "~this";
			kind = SymbolType.Function;
			break;
		default:
			if (func.type.isProperty) {
				kind = SymbolType.Property;
			} else {
				kind = SymbolType.Function;
			}
			break;
		}
		addSymbol(func, name, kind);
		return Status.Continue;
	}

	override fn enter(strct: ir.Struct) Status
	{
		addSymbol(strct, strct.name, SymbolType.Class);
		parents ~= strct.name;
		return Status.Continue;
	}

	override fn leave(strct: ir.Struct) Status
	{
		assert(parents.length > 0);
		parents = parents[0 .. $-1];
		return Status.Continue;
	}

	override fn enter(clss: ir.Class) Status
	{
		addSymbol(clss, clss.name, SymbolType.Class);
		parents ~= clss.name;
		return Status.Continue;
	}

	override fn leave(clss: ir.Class) Status
	{
		assert(parents.length > 0);
		parents = parents[0 .. $-1];
		return Status.Continue;
	}

	override fn enter(intrfc: ir._Interface) Status
	{
		addSymbol(intrfc, intrfc.name, SymbolType.Interface);
		parents ~= intrfc.name;
		return Status.Continue;
	}

	override fn leave(intrfc: ir._Interface) Status
	{
		assert(parents.length > 0);
		parents = parents[0 .. $-1];
		return Status.Continue;
	}

	override fn enter(var: ir.Variable) Status
	{
		kind: i32;
		switch (var.storage) with (ir.Variable.Storage) {
		case Field:
			kind = SymbolType.Field;
			break;
		case Global:
		case Local:
			kind = SymbolType.Variable;
			break;
		default:
			return Status.Continue;
		}
		addSymbol(var, var.name, kind);
		return Status.Continue;
	}

	override fn enter(enm: ir.EnumDeclaration) Status
	{
		addSymbol(enm, enm.name, SymbolType.Enum);
		return Status.Continue;
	}

private:
	fn addSymbol(node: ir.Node, name: string, type: i32)
	{
		sym: Symbol;
		sym.name = name;
		if (parents.length > 0) {
			sym.containerName = parents[$-1];
		}
		sym.loc = node.loc;
		sym.type = type;
		symbols ~= sym;
	}
}
