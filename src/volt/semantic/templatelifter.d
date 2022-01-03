/*#D*/
// Copyright 2017, Jakob Bornecrantz.
// Copyright 2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module volt.semantic.templatelifter;

import watt.text.format;
import watt.io.std;

import ir = volta.ir;
import ircopy = volta.util.copy;
import volta.util.util;
import volta.util.dup;

import volt.errors;
import volt.interfaces;

import volt.ir.lifter;

import volta.visitor.visitor;

import volta.postparse.gatherer : Gatherer;
import volta.postparse.attribremoval : AttribRemoval, applyAttribute;
import volta.postparse.scopereplacer : ScopeReplacer;

import volt.semantic.lookup;
import volt.semantic.extyper;
import volt.semantic.classify;
import volt.semantic.typer;
import volt.semantic.mangle;
import volt.semantic.typeinfo;


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
		auto f = new ir.Function(old);
		liftInPlace(old, /*#ref*/f);
		return f;
	}

	void liftInPlace(ir.Function old, ref ir.Function f)
	{
		// These should never be set.
		if (old.myScope !is null) { throw panic("invalid templated function"); }
		if (old.thisHiddenParameter !is null) { throw panic("invalid templated function"); }
		if (old.nestedHiddenParameter !is null) { throw panic("invalid templated function"); }
		if (old.nestedVariable !is null) { throw panic("invalid templated function"); }
		if (old.nestStruct !is null) { throw panic("invalid templated function"); }
		if (old.nestedFunctions !is null) { throw panic("invalid templated function"); }

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
		if (old.hasInContract) {
			if (f.parsedIn !is null) {
				f.parsedIn = copy(null, old.parsedIn);
			} else {
				f.tokensIn = f.tokensIn.dup();
			}
		}
		if (old.hasOutContract) {
			if (f.parsedOut !is null) {
				f.parsedOut = copy(null, old.parsedOut);
			} else {
				f.tokensOut = f.tokensOut.dup();
			}
		}
		if (old.hasBody) {
			if (f.parsedBody !is null) {
				f.parsedBody = copy(null, old.parsedBody);
			} else {
				f.tokensBody = f.tokensBody.dup();
			}
		}

		f.templateName = currentTemplateDefinitionName;
		f.templateType = currentInstanceType;
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
		n.targetModules = new ir.Module[](old.targetModules.length);
		for (size_t i = 0; i < n.targetModules.length; ++i) {
			n.targetModules[i] = lift(old.targetModules[i]);
		}
		return n;
	}

	ir.Module lift(ir.Module old)
	{
		auto n = new ir.Module(old);
		n.children = lift(old.children);
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
			n.type = buildTypeReference(/*#ref*/en.loc, en, en.name);
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
		if (old.staticIf !is null) {
			a.staticIf = copyAliasStaticIf(old.staticIf);
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
		if (old.vtableVariable !is null) {
			c.vtableVariable = lift(old.vtableVariable);
		}
		if (old.classinfoVariable !is null) {
			c.classinfoVariable = lift(old.classinfoVariable);
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
	void templateLift(ir.Scope _current, LanguagePass lp, ir.TemplateInstance ti)
	{
		ti.oldParent = ti.myScope.parent;
		switch (ti.kind) with (ir.TemplateKind) {
		case Struct, Class, Union, Interface:
			templateLiftAggregate(_current, lp, ti);
			break;
		case Function:
			templateLiftFunction(_current, lp, ti);
			break;
		default:
			throw makeError(/*#ref*/ti.loc, "non struct/class/union/interface/function template");
		}
	}

	void templateLiftFunction(ir.Scope _current, LanguagePass lp, ir.TemplateInstance ti)
	{
		auto current = ti.myScope;
		auto td = getNewTemplateDefinition(current, lp, ti);
		panicAssert(ti, current !is null);

		if (!ti.explicitMixin) {
			ti.myScope.parent = td.myScope.parent;
		}

		auto deffunc = td._function;
		panicAssert(ti, deffunc !is null);

		auto func = lift(deffunc);
		func.name = ti.instanceName;
		func.kind = ir.Function.Kind.Function;
		func.myScope = new ir.Scope(current, func, func.name, current.nestedDepth);
		ti._function = func;

		currentTemplateDefinitionName = td.name;

		auto processed = processNewTemplateArguments(lp, func.myScope.parent, ti.myScope, td, ti);

		foreach (var; func.params) {
			if (var.name !is null) {
				ir.Status status;
				func.myScope.addValue(var, var.name, /*#out*/status);
				if (status != ir.Status.Success) {
					throw panic(/*#ref*/func.loc, "value redefinition");
				}
			}
		}

		// Useless error checking?
		panicAssert(ti, func.myScope !is null);
		panicAssert(ti, func.myScope.parent !is null);
		panicAssert(ti, func.myScope.parent.parent !is null);
		panicAssert(ti, func.myScope.parent.parent.node !is null);
		if (func.myScope.parent.parent.node.nodeType != ir.NodeType.Module) {
			throw makeError(/*#ref*/func.loc, "non top level template function.");
		}

		// Handle arguements.
		addArgumentsToNewInstanceEnvironment(lp, processed, func.myScope, td, ti);

		// We only need to add the function, unlike with Aggregates.
		auto store = ti.oldParent.getStore(ti.instanceName);
		panicAssert(ti, store !is null);
		panicAssert(ti, store.kind == ir.Store.Kind.Merge); // Always merge
		store.functions ~= func;
	}

	void templateLiftAggregate(ir.Scope _current, LanguagePass lp, ir.TemplateInstance ti)
	{
		auto current = ti.myScope;
		auto td = getNewTemplateDefinition(current, lp, ti);

		if (!ti.explicitMixin) {
			ti.myScope.parent = td.myScope.parent;
		}

		ir.Aggregate defAgg;
		ir.Aggregate a;
		switch (ti.kind) with (ir.TemplateKind) {
		case Class:
			defAgg = td._class;
			a = new ir.Class(td._class);
			ti._class = a.toClassFast();
			break;
		case Struct:
			defAgg = td._struct;
			a = new ir.Struct(td._struct);
			ti._struct = a.toStructFast();
			break;
		case Union:
			defAgg = td._union;
			a = new ir.Union(td._union);
			ti._union = a.toUnionFast();
			break;
		case Interface:
			defAgg = td._interface;
			a = new ir._Interface(td._interface);
			ti._interface = a.toInterfaceFast();
			break;
		default:
			panicAssert(ti, false);
		}
		a.name = ti.instanceName;
		panicAssert(ti, a.name !is null);
		a.myScope = new ir.Scope(current, a, a.name, current.nestedDepth);

		currentTemplateDefinitionName = td.name;
		currentInstanceType = a;

		// Make sure we look in the scope where the template inst. is.
		auto processed = processNewTemplateArguments(lp, a.myScope.parent, current, td, ti);

		// Do the lifting of the children.
		a.members = lift(defAgg.members);

		// Setup any passes that need to process the copied nodes.
		auto mod = getModuleFromScope(/*#ref*/a.loc, current);
		auto gatherer = new Gatherer(/*warnings*/false, lp.errSink);

		// Run the gatherer.
		gatherer.push(a.myScope);
		accept(a, gatherer);

		// Handle arguments.
		addArgumentsToNewInstanceEnvironment(lp, processed, a.myScope, td, ti);
		ensureMangled(a);

		auto store = ti.oldParent.getStore(ti.instanceName);
		panicAssert(ti, store !is null);
		panicAssert(ti, store.node is ti);
		panicAssert(ti, store.kind == ir.Store.Kind.TypeTemplateInstance);

		store.markTypeTemplateInstanceResolved(a, a.myScope);
	}

private:
	void addArgumentsToNewInstanceEnvironment(LanguagePass lp, ir.Node[] processed, ir.Scope instanceScope,
	ir.TemplateDefinition td, ir.TemplateInstance ti)
	{
		foreach (param; td.parameters) {
			if (param.type !is null) {
				auto tr = param.type.toTypeReferenceChecked();
				if (tr !is null) {
					if (tr.id.identifiers.length == 1 && tr.id.identifiers[0].value == param.name) {
						throw makeError(/*#ref*/td.loc, "template definition parameter name cannot be the same as the type name.");
					}
				}
			}
			ti.names ~= param.name;
		}
		foreach (i, ref arg; ti.arguments) {
			auto name = td.parameters[i].name;
			auto store = instanceScope.getStore(name);
			if (store !is null) {
				throw makeRedefinesReservedIdentifier(/*#ref*/store.node.loc, name);
			}

			if (auto a = cast(ir.Alias)processed[i]) {
				// Add the alias to the scope and set its store.
				ir.Status status;
				a.store = ti.myScope.addAlias(a, a.name, /*#out*/status);
				if (status != ir.Status.Success) {
					throw panic(/*#ref*/a.loc, "alias redefines symbol");
				}

				// Do the lookup here.
				lp.resolveAlias(a);

				// Make sure that the alias we got is a type.
				assert(a.store.myAlias !is null);
				bool typeAlias = false;
				if (auto type = cast(ir.Type)a.store.myAlias.node) {
					typeAlias = true;
				} else if (auto _ti = cast(ir.TemplateInstance)a.store.myAlias.node) {
					typeAlias = _ti.kind != ir.TemplateKind.Function;
				}

				if (!typeAlias) {
					throw makeExpected(arg, "type");
				}
			} else if (auto type = cast(ir.Type)processed[i]) {
				ir.Status status;
				ti.myScope.addType(type, name, /*#out*/status);
				if (status != ir.Status.Success) {
					throw panic(/*#ref*/type.loc, "template type addition redefinition");
				}
			} else if (auto exp = cast(ir.Exp)processed[i]) {
				auto type = copyType(td.parameters[i].type);
				auto ed = buildEnumDeclaration(/*#ref*/ti.loc, type, exp, name);
				ir.Status status;
				ti.myScope.addEnumDeclaration(ed, /*#out*/status);
				if (status != ir.Status.Success) {
					throw panic(/*#ref*/ti.loc, "enum declaration redefinition");
				}
			} else {
				throw makeExpected(/*#ref*/arg.loc, "expression or type");
			}
		}
	}
}

private:

alias NodeAdder = void delegate(ir.Node);

ir.TemplateDefinition getNewTemplateDefinition(ir.Scope current, LanguagePass lp, ir.TemplateInstance ti)
{
	auto store = lookup(lp, current, ti.definitionName);
	if (store is null) {
		throw makeFailedLookup(/*#ref*/ti.loc, ti.definitionName.toString());
	}
	auto td = cast(ir.TemplateDefinition)store.node;
	if (td is null) {
		throw makeError(/*#ref*/ti.loc, format("'%s' is not a template definition", ti.definitionName.toString()));
	}
	if (ti.arguments.length != td.parameters.length) {
		throw makeExpected(ti, format("%s argument%s", td.parameters.length,
			td.parameters.length == 1 ? "" : "s"));
	}
	if (ti.kind != td.kind) {
		throw makeMismatchedTemplateInstanceAndDefinition(/*#ref*/ti.loc, ti.kind, td.kind);
	}
	return td;
}

/*
 * Given the definintion and instance, return a new list with
 * resolved types of template instance arguments.
 * (The expressions will be untouched, but in the
 * new list also)
 *
 * The output list will be the same length as the instance's
 * argument list, and will be in the same order.
 */
ir.Node[] processNewTemplateArguments(LanguagePass lp, ir.Scope lookScope, ir.Scope newScope, ir.TemplateDefinition td, ir.TemplateInstance ti)
{
	auto processed = new ir.Node[](ti.arguments.length);
	// Loop over all arguments.
	foreach (i, ref arg; ti.arguments) {

		if (td.parameters[i].type !is null) {

			// This is a expression.
			processed[i] = arg;

		} else if (auto type = cast(ir.Type)arg) {

			// A simple type like 'u32' or 'typeof(Foo)'
			resolveType(lp, lookScope, /*#ref*/type);
			processed[i] = type;

		} else {

			// A qname like 'pkg.mod.Struct'
			auto exp = cast(ir.Exp)arg;
			if (exp is null) {
				throw makeExpected(arg, "type");
			}

			// In order to properly set the store up as a
			// alias to types we need to resolve the alias
			// like normal aliases via the lp.
			auto a = new ir.Alias();
			a.loc = arg.loc;
			a.isResolved = true;
			a.name = td.parameters[i].name;
			a.lookScope = lookScope;
			a.access = ir.Access.Public;
			a.id = exptoQualifiedName(exp);

			// We don't do any lookup/resolving here
			// because we need a.store to be a proper store
			// that will still around.
			processed[i] = a;
		}
	}
	return processed;
}

/*
 * Given a Type that's been smuggled in as an expression (it'll either be an
 * IdentifierExp or a QualifiedName as a Postfix chain), return a QualifiedName,
 * or throw an error.
 *
 * The template parser can't tell if it needs to parse an expression or a type,
 * so for user defined types it has to parse them as an expression. By the time
 * we see them, we know they're types, so the postfix will be unprocessed, and
 * we can do things like this.
 */
ir.QualifiedName exptoQualifiedName(ir.Exp exp, ir.QualifiedName qname = null)
{
	if (qname is null) {
		qname = new ir.QualifiedName();
		qname.loc = exp.loc;
	}
	if (exp.nodeType == ir.NodeType.IdentifierExp) {
		auto iexp = exp.toIdentifierExpFast();
		auto ident = new ir.Identifier(iexp.value);
		ident.loc = iexp.loc;
		qname.identifiers ~= ident;
	} else if (exp.nodeType == ir.NodeType.Postfix) {
		auto postfix = exp.toPostfixFast();
		if (postfix.identifier is null) {
			throw makeExpected(exp, "type");
		}
		exptoQualifiedName(postfix.child, qname);
		qname.identifiers ~= postfix.identifier;
	} else {
		throw makeExpected(exp, "type");
	}
	return qname;
}
