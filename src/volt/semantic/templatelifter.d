// Copyright © 2017, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.templatelifter;

import watt.text.format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;

import volt.ir.lifter;

import volt.visitor.visitor;

import volt.postparse.gatherer : Gatherer;
import volt.postparse.attribremoval : AttribRemoval;
import volt.postparse.scopereplacer : ScopeReplacer;

import volt.semantic.lookup;
import volt.semantic.extyper;
import volt.semantic.classify;


class TemplateLifter : Lifter
{
public:
	string currentTemplateDefinitionName;
	ir.Type currentInstanceType;

public:
	override ir.TopLevelBlock lift(ir.TopLevelBlock old)
	{
		auto tlb = new ir.TopLevelBlock(old);
		foreach (ref n; tlb.nodes) {
			switch (n.nodeType) with (ir.NodeType) {
			case Function:
				auto func = cast(ir.Function)n;
				n = lift(func);
				break;
			case Variable:
				auto var = cast(ir.Variable)n;
				n = lift(var);
				break;
			case Struct:
				auto s = cast(ir.Struct)n;
				n = lift(s);
				break;
			case Union:
				auto u = cast(ir.Union)n;
				n = lift(u);
				break;
			case Interface:
				auto _i = cast(ir._Interface)n;
				n = lift(_i);
				break;
			case Class:
				auto c = cast(ir.Class)n;
				n = lift(c);
				break;
			case Import:
				auto i = cast(ir.Import)n;
				n = lift(i);
				break;
			case Enum:
				auto e = cast(ir.Enum)n;
				n = lift(e);
				break;
			case EnumDeclaration:
				auto e = cast(ir.EnumDeclaration)n;
				n = lift(null, e);
				break;
			case AssertStatement:
				n = copyStatement(null, cast(ir.AssertStatement)n);
				break;
			case Alias:
				auto a = cast(ir.Alias)n;
				n = lift(a);
				break;
			default:
				throw panic(n, "not implemented!");
			}
		}
		return tlb;
	}

	override ir.Function lift(ir.Function old)
	{
		// These should never be set.
		if (old.myScope !is null) { throw panic("invalid templated function"); }
		if (old.thisHiddenParameter !is null) { throw panic("invalid templated function"); }
		if (old.nestedHiddenParameter !is null) { throw panic("invalid templated function"); }
		if (old.nestedVariable !is null) { throw panic("invalid templated function"); }
		if (old.nestStruct !is null) { throw panic("invalid templated function"); }
		if (old.nestedFunctions !is null) { throw panic("invalid templated function"); }

		// Do a deep copy of the function.
		auto f = new ir.Function(old);

		// Copy params.
		foreach (ref p; f.params) {
			p = lift(p);
			p.func = f;
		}

		foreach (ref sf; f.scopeSuccesses) {
			sf = lift(sf);
		}

		foreach (ref sf; f.scopeExits) {
			sf = lift(sf);
		}

		foreach (ref sf; f.scopeFailures) {
			sf = lift(sf);
		}

		f.type = copy(old.type);
		if (old.inContract !is null) {
			f.inContract = copy(null, old.inContract);
		}
		if (old.outContract!is null) {
			f.outContract = copy(null, old.outContract);
		}
		if (old._body !is null) {
			f._body = copy(null, old._body);
		}

		return f;
	}

	override ir.FunctionParam lift(ir.FunctionParam old)
	{
		auto p = new ir.FunctionParam(old);
		if (old.assign !is null) {
			p.assign = copyExp(old.assign);
		}
		return p;
	}

	override ir.Variable lift(ir.Variable n)
	{
		auto v = new ir.Variable(n);
		v.type = copyType(n.type);
		if (n.assign !is null) {
			v.assign = copyExp(n.assign);
		}
		return v;
	}

	ir.Import lift(ir.Import old)
	{
		auto n = new ir.Import(old);
		if (old.targetModule !is null) {
			n.targetModule = lift(old.targetModule);
		}
		return n;
	}

	ir.Module lift(ir.Module old)
	{
		auto n = new ir.Module(old);
		n.children = lift(old.children);
		n.moduleInfo = lift(old.moduleInfo);
		n.moduleInfoRoot = lift(old.moduleInfoRoot);
		return n;
	}

	ir.Aggregate lift(ir.Aggregate old)
	{
		switch (old.nodeType) with (ir.NodeType) {
		case Class: return lift(cast(ir.Class)old);
		case Interface: return lift(cast(ir._Interface)old);
		case Struct: return lift(cast(ir.Struct)old);
		case Union: return lift(cast(ir.Union)old);
		default:
			throw panic(old, "not implemented!");
		}
	}

	override ir.Enum lift(ir.Enum old)
	{
		auto n = new ir.Enum(old);
		foreach (i, ref edecl; n.members) {
			edecl = lift(n, old.members[i]);
		}
		if (old.base !is null) {
			n.base = copyType(old.base);
		}
		return n;
	}

	ir.EnumDeclaration lift(ir.Enum en, ir.EnumDeclaration old)
	{
		auto n = new ir.EnumDeclaration(old);
		if (en !is null) {
			n.type = buildTypeReference(en.loc, en, en.name);
		} else {
			n.type = copyType(old.type);
		}
		if (old.assign !is null) {
			n.assign = copyExp(old.assign);
		}
		if (old.prevEnum !is null) {
			n.prevEnum = lift(en, old.prevEnum);
		}
		return n;
	}

	override ir.Alias lift(ir.Alias old)
	{
		auto a = new ir.Alias(old);
		if (old.id !is null) {
			a.id = copyQualifiedName(old.id);
		}
		if (old.type !is null) {
			a.type = copyType(old.type);
		}
		return a;
	}

	override ir.Struct lift(ir.Struct old)
	{
		auto s = new ir.Struct(old);
		foreach (i, ref anonagg; s.anonymousAggregates) {
			anonagg = lift(old.anonymousAggregates[i]);
		}
		foreach (i, ref anonvar; s.anonymousVars) {
			anonvar = lift(old.anonymousVars[i]);
		}
		s.members = lift(old.members);
		foreach (i, ref ctor; s.constructors) {
			ctor = lift(old.constructors[i]);
		}
		return s;
	}

	override ir.Union lift(ir.Union old)
	{
		auto s = new ir.Union(old);
		foreach (i, ref anonagg; s.anonymousAggregates) {
			anonagg = lift(old.anonymousAggregates[i]);
		}
		foreach (i, ref anonvar; s.anonymousVars) {
			anonvar = lift(old.anonymousVars[i]);
		}
		s.members = lift(old.members);
		foreach (i, ref ctor; s.constructors) {
			ctor = lift(old.constructors[i]);
		}
		return s;
	}

	override ir.Class lift(ir.Class old)
	{
		// These should never be set.
		if (old.myScope !is null) { throw panic("invalid templated class"); }
		if (old.parentClass !is null) { throw panic("invalid templated class"); }
		if (old.layoutStruct !is null) { throw panic("invalid templated class"); }
		if (old.parentInterfaces.length > 0) { throw panic("invalid templated class"); }
		if (old.interfaceOffsets.length > 0) { throw panic("invalid templated class"); }
		if (old.anonymousAggregates.length > 0) { throw panic("invalid templated class"); }
		if (old.anonymousVars.length > 0) { throw panic("invalid templated class"); }

		auto c = new ir.Class(old);
		foreach (i, ref ctor; c.userConstructors) {
			ctor = lift(old.userConstructors[i]);
		}
		if (old.vtableStruct !is null) {
			c.vtableStruct = lift(old.vtableStruct);
		}
		if (old.vtableVariable !is null) {
			c.vtableVariable = lift(old.vtableVariable);
		}
		foreach (i, ref var; c.ifaceVariables) {
			var = lift(old.ifaceVariables[i]);
		}
		if (old.initVariable !is null) {
			c.initVariable = lift(old.initVariable);
		}
		c.members = lift(old.members);
		return c;
	}

	override ir._Interface lift(ir._Interface old)
	{
		if (old.myScope !is null) { throw panic("invalid templated class"); }
		if (old.layoutStruct !is null) { throw panic("invalid templated class"); }
		if (old.parentInterfaces.length > 0) { throw panic("invalid templated class"); }
		if (old.anonymousAggregates.length > 0) { throw panic("invalid templated class"); }
		if (old.anonymousVars.length > 0) { throw panic("invalid templated class"); }

		auto _i = new ir._Interface(old);
		foreach (i, ref iface; _i.parentInterfaces) {
			iface = lift(old.parentInterfaces[i]);
		}
		if (old.layoutStruct !is null) {
			_i.layoutStruct = lift(old.layoutStruct);
		}
		foreach (i, ref anonagg; _i.anonymousAggregates) {
			anonagg = lift(old.anonymousAggregates[i]);
		}
		foreach (i, ref anonvar; _i.anonymousVars) {
			anonvar = lift(old.anonymousVars[i]);
		}
		_i.members = lift(old.members);
		return _i;
	}

	override ir.Node liftedOrPanic(ir.Node node, string msg) { throw panic(node, msg); }

	override ir.BlockStatement copy(ir.Scope parent, ir.BlockStatement old)
	{
		assert(old !is null);
		assert(old.myScope is null);
		assert(parent is null);

		auto n = new ir.BlockStatement(old);

		foreach (ref stat; n.statements) {
			stat = copyStatement(n.myScope, stat);
		}

		return n;
	}

	// Volt can't do the "alias copy = super.copy" trick as D.
	override ir.FunctionType copy(ir.FunctionType old) { return super.copy(old); }

	override ir.TypeReference copy(ir.TypeReference old)
	{
		auto tr = super.copy(old);
		if (tr.id.identifiers.length == 1 &&
			tr.id.identifiers[0].value == currentTemplateDefinitionName) {
			tr.type = currentInstanceType;
		}
		return tr;
	}


public:
	void templateLift(ref ir.Struct s, LanguagePass lp, ir.TemplateInstance ti)
	{
		auto current = s.myScope;
		if (!ti.explicitMixin) {
			throw makeExpected(ti.loc, "explicit mixin");
		}
		auto store = lookup(lp, current, ti.loc, ti.name);
		assert(store !is null);
		auto td = cast(ir.TemplateDefinition)store.node;
		assert(td !is null);
		auto defstruct = td._struct;
		panicAssert(s, defstruct !is null);

		currentTemplateDefinitionName = td.name;
		currentInstanceType = s;

		foreach (i, ref type; ti.typeArguments) {
			assert(type !is null);
			auto tr = cast(ir.TypeReference)type;
			resolveType(lp, current, type);
			if (isTemplateInstance(type)) {
				panicAssert(s, tr !is null);
				throw makeTemplateAsTemplateArg(ti.loc, tr.id.toString());
			}
			auto name = td.typeParameters[i];
			s.myScope.reserveId(td, name);
		}
		s.members = lift(defstruct.members);

		// Setup any passes that needs to procces the copied nodes.
		auto mod = getModuleFromScope(s.loc, current);
		auto gatherer = new Gatherer(/*warnings*/false);

		// Run the gatherer.
		gatherer.push(s.myScope);
		accept(s, gatherer);
		s.templateInstance.typeNames = td.typeParameters;
		foreach (i, ref type; ti.typeArguments) {
			auto name = td.typeParameters[i];
			s.myScope.remove(name);
			s.myScope.addType(type, name);
		}
	}

private:
	bool isTemplateInstance(ir.Type t)
	{
		auto _struct = cast(ir.Struct)realType(t);
		return _struct !is null && _struct.templateInstance !is null;
	}
}
