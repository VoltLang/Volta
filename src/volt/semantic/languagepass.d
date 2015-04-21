// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.languagepass;

import std.stdio : stdout;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.errors;

import volt.token.location;

import volt.util.worktracker;

import volt.visitor.debugprinter;
import volt.visitor.prettyprinter;

import volt.semantic.util;
import volt.semantic.lookup;
import volt.semantic.classify;
import volt.semantic.typeinfo;

import volt.semantic.extyper;
import volt.semantic.gatherer;
import volt.semantic.irverifier;
import volt.semantic.condremoval;
import volt.semantic.newreplacer;
import volt.semantic.llvmlowerer;
import volt.semantic.manglewriter;
import volt.semantic.attribremoval;
import volt.semantic.typeidreplacer;
import volt.semantic.importresolver;
import volt.semantic.ctfe;
import volt.semantic.cfg;

import volt.semantic.resolver;
import volt.semantic.classresolver;
import volt.semantic.aliasresolver;
import volt.semantic.userattrresolver;
import volt.semantic.strace;


/**
 * Default implementation of
 * @link volt.interfaces.LanguagePass LanguagePass@endlink, replace
 * this if you wish to any of the semantics of the language.
 */
class VoltLanguagePass : LanguagePass
{
public:
	/**
	 * Phases fields.
	 * @{
	 */
	Pass[] postParse;
	Pass[] passes2;
	Pass[] passes3;
	/**
	 * @}
	 */

private:
	WorkTracker mTracker;
	ir.Module[string] mModules;

public:
	this(Settings settings, Frontend frontend, Controller controller)
	{
		super(settings, frontend, controller);

		mTracker = new WorkTracker();

		postParse ~= new ConditionalRemoval(this);
		if (settings.removeConditionalsOnly) {
			return;
		}
		postParse ~= new AttribRemoval(this);
		postParse ~= new Gatherer(this);

		passes2 ~= new SimpleTrace(this);
		passes2 ~= new ExTyper(this);
		passes2 ~= new CFGBuilder(this);
		passes2 ~= new IrVerifier();

		passes3 ~= new LlvmLowerer(this);
		passes3 ~= new NewReplacer(this);
		passes3 ~= new TypeidReplacer(this);
		passes3 ~= new MangleWriter(this);
		passes3 ~= new IrVerifier();
	}

	/**
	 * This functions sets up the pointers to the often used
	 * inbuilt classes, such as object.Object and object.TypeInfo.
	 * This needs to be called after the Controller is fully setup.
	 */
	void setupOneTruePointers()
	{
		objectModule = getModule(buildQualifiedName(Location(), "object"));
		if (objectModule is null) {
			throw panic("could not find object module");
		}

		void check(ir.Node n, string name)
		{
			if (n is null) {
				throw panic(format("can't find runtime object '%s'.", name));
			}
		}

		// Run postParse passes so we can lookup things.
		phase1(objectModule);

		if (settings.removeConditionalsOnly) {
			return;
		}

		// Get the classes.
		auto s = objectModule.myScope;
		objectClass = cast(ir.Class)s.getStore("Object").node;
		check(objectClass, "Object");
		typeInfoClass = cast(ir.Class)s.getStore("TypeInfo").node;
		check(typeInfoClass, "TypeInfo");
		attributeClass = cast(ir.Class)s.getStore("Attribute").node;
		check(attributeClass, "Attribute");
		assertErrorClass = cast(ir.Class)s.getStore("AssertError").node;
		check(assertErrorClass, "AssertError");
		arrayStruct = cast(ir.Struct)s.getStore("ArrayStruct").node;
		check(arrayStruct, "ArrayStruct");
		allocDgVariable = cast(ir.Variable)s.getStore("allocDg").node;
		check(allocDgVariable, "allocDg");

		// VA
		vaStartFunc = cast(ir.Function)s.getStore("__volt_va_start").node;
		check(vaStartFunc, "__volt_va_start");
		vaEndFunc = cast(ir.Function)s.getStore("__volt_va_end").node;
		check(vaEndFunc, "__volt_va_end");
		vaCStartFunc = cast(ir.Function)s.getStore("__llvm_volt_va_start").node;
		check(vaCStartFunc, "__llvm_volt_va_start");
		vaCEndFunc = cast(ir.Function)s.getStore("__llvm_volt_va_end").node;
		check(vaCEndFunc, "__llvm_volt_va_end");

		// Util
		hashFunc = cast(ir.Function)s.getStore("vrt_hash").node;
		check(hashFunc, "vrt_hash");
		castFunc = cast(ir.Function)s.getStore("vrt_handle_cast").node;
		check(castFunc, "vrt_handle_cast");
		printfFunc = cast(ir.Function)s.getStore("vrt_printf").node;
		check(printfFunc, "vrt_printf");
		memcpyFunc = cast(ir.Function)s.getStore("__llvm_memcpy_p0i8_p0i8_i32").node;
		check(memcpyFunc, "__llvm_memcpy_p0i8_p0i8_i32");
		memcmpFunc = cast(ir.Function)s.getStore("vrt_memcmp").node;
		check(memcmpFunc, "vrt_memcmp");

		// EH
		ehThrowFunc = cast(ir.Function)s.getStore("vrt_eh_throw").node;
		check(ehThrowFunc, "vrt_eh_throw");
		ehThrowSliceErrorFunc = cast(ir.Function)s.getStore("vrt_eh_throw_slice_error").node;
		check(ehThrowSliceErrorFunc, "vrt_eh_throw_slice_error");
		ehPersonalityFunc = cast(ir.Function)s.getStore("vrt_eh_personality_v0").node;
		check(ehPersonalityFunc, "vrt_eh_personality_v0");

		// AA
		aaGetKeys = cast(ir.Function)s.getStore("vrt_aa_get_keys").node;
		check(aaGetKeys, "vrt_aa_get_keys");
		aaGetValues = cast(ir.Function)s.getStore("vrt_aa_get_values").node;
		check(aaGetValues, "vrt_aa_get_values");
		aaGetLength = cast(ir.Function)s.getStore("vrt_aa_get_length").node;
		check(aaGetLength, "vrt_aa_get_length");
		aaInArray = cast(ir.Function)s.getStore("vrt_aa_in_binop_array").node;
		check(aaInArray, "vrt_aa_in_binop_array");
		aaInPrimitive = cast(ir.Function)s.getStore("vrt_aa_in_binop_primitive").node;
		check(aaInPrimitive, "vrt_aa_in_binop_primitive");
		aaRehash = cast(ir.Function)s.getStore("vrt_aa_rehash").node;
		check(aaRehash, "vrt_aa_rehash");
		aaGetPP = cast(ir.Function)s.getStore("vrt_aa_get_pp").node;
		check(aaGetPP, "vrt_aa_get_pp");
		aaGetAA = cast(ir.Function)s.getStore("vrt_aa_get_aa").node;
		check(aaGetAA, "vrt_aa_get_aa");
		aaGetAP = cast(ir.Function)s.getStore("vrt_aa_get_ap").node;
		check(aaGetAP, "vrt_aa_get_ap");
		aaGetPA = cast(ir.Function)s.getStore("vrt_aa_get_pa").node;
		check(aaGetPA, "vrt_aa_get_pa");

		ir.EnumDeclaration getEnum(string name)
		{
			auto ed = cast(ir.EnumDeclaration)s.getStore(name).node;
			assert(ed !is null);
			return ed;
		}

		TYPE_STRUCT = getEnum("TYPE_STRUCT");
		TYPE_CLASS = getEnum("TYPE_CLASS");
		TYPE_INTERFACE = getEnum("TYPE_INTERFACE");
		TYPE_UNION = getEnum("TYPE_UNION");
		TYPE_ENUM = getEnum("TYPE_ENUM");
		TYPE_ATTRIBUTE = getEnum("TYPE_ATTRIBUTE");
		TYPE_USER_ATTRIBUTE = getEnum("TYPE_USER_ATTRIBUTE");
		TYPE_VOID = getEnum("TYPE_VOID");
		TYPE_UBYTE = getEnum("TYPE_UBYTE");
		TYPE_BYTE = getEnum("TYPE_BYTE");
		TYPE_CHAR = getEnum("TYPE_CHAR");
		TYPE_BOOL = getEnum("TYPE_BOOL");
		TYPE_USHORT = getEnum("TYPE_USHORT");
		TYPE_SHORT = getEnum("TYPE_SHORT");
		TYPE_WCHAR = getEnum("TYPE_WCHAR");
		TYPE_UINT = getEnum("TYPE_UINT");
		TYPE_INT = getEnum("TYPE_INT");
		TYPE_DCHAR = getEnum("TYPE_DCHAR");
		TYPE_FLOAT = getEnum("TYPE_FLOAT");
		TYPE_ULONG = getEnum("TYPE_ULONG");
		TYPE_LONG = getEnum("TYPE_LONG");
		TYPE_DOUBLE = getEnum("TYPE_DOUBLE");
		TYPE_REAL = getEnum("TYPE_REAL");
		TYPE_POINTER = getEnum("TYPE_POINTER");
		TYPE_ARRAY = getEnum("TYPE_ARRAY");
		TYPE_STATIC_ARRAY = getEnum("TYPE_STATIC_ARRAY");
		TYPE_AA = getEnum("TYPE_AA");
		TYPE_FUNCTION = getEnum("TYPE_FUNCTION");
		TYPE_DELEGATE = getEnum("TYPE_DELEGATE");

		phase2([objectModule]);
	}

	override ir.Module getModule(ir.QualifiedName name)
	{ 
		return controller.getModule(name);
	}


	/*
	 *
	 * Resolver functions.
	 *
	 */


	override void gather(ir.Scope current, ir.BlockStatement bs)
	{
		auto g = new Gatherer(this);
		g.transform(current, bs);
		g.close();
	}

	override void resolve(ir.Scope current, ir.TypeReference tr)
	{
		if (tr.type !is null)
			return;

		auto w = mTracker.add(tr, "resolving type");
		scope (exit)
			w.done();

		tr.type = lookupType(this, current, tr.id);
	}

	override void resolve(ir.Scope current, ir.Variable v)
	{
		if (v.isResolved)
			return;

		auto w = mTracker.add(v, "resolving variable");
		scope (exit)
			w.done();

		resolve(current, v.userAttrs);

		auto e = new ExTyper(this);
		e.transform(current, v);

		v.isResolved = true;
	}

	override void resolve(ir.Scope current, ir.Function fn)
	{
		if ((fn.kind == ir.Function.Kind.Function || (cast(ir.Class) current.node) is null) && fn.isMarkedOverride) {
			throw makeMarkedOverrideDoesNotOverride(fn, fn);
		}
		ensureResolved(this, current, fn.type);
		replaceVarArgsIfNeeded(this, fn);
		foreach (ref param; fn.params) {
			if (param.assign !is null) {
				auto texp = cast(ir.TokenExp) param.assign;
				if (texp is null) {
					param.assign = evaluate(this, current, param.assign);
				}
			}
		}
		resolve(current, fn.userAttrs);
	}

	override void resolve(ir.Alias a)
	{
		if (!a.resolved)
			resolve(a.store);
	}

	override void resolve(ir.Store s)
	{
		auto w = mTracker.add(s.node, "resolving alias");
		scope (exit)
			w.done();

		resolveAlias(this, s);
	}

	override void resolve(ir.Scope current, ir.Attribute a)
	{
		if (!needsResolving(a)) {
			return;
		}

		auto e = new ExTyper(this);
		e.transform(current, a);
	}

	override void resolve(ir.Enum e)
	{
		if (e.resolved) {
			return;
		}

		resolveEnum(this, e);
	}

	override void resolve(ir.Scope current, ir.EnumDeclaration ed)
	{
		if (ed.resolved) {
			return;
		}

		auto e = new ExTyper(this);
		e.transform(current, ed);
	}

	override void resolve(ir.Scope current, ir.AAType at)
	{
		ensureResolved(this, current, at.value);
		ensureResolved(this, current, at.key);

		auto base = at.key;

		auto tr = cast(ir.TypeReference)base;
		if (tr !is null) {
			base = tr.type;
		}

		if (base.nodeType() == ir.NodeType.Struct || base.nodeType() == ir.NodeType.Class) {
			return;
		}

		if (base.nodeType() == ir.NodeType.ArrayType) {
			base = (cast(ir.ArrayType)base).base;
		} else if (base.nodeType() == ir.NodeType.StaticArrayType) {
			base = (cast(ir.StaticArrayType)base).base;
		}

		auto st = cast(ir.StorageType)base;
		if (st !is null &&
	  	    (st.type == ir.StorageType.Kind.Immutable ||
		     st.type == ir.StorageType.Kind.Const)) {
			base = st.base;
		}

		auto prim = cast(ir.PrimitiveType)base;
		if (prim !is null) {
			return;
		}

		throw makeInvalidAAKey(at);
	}

	override void doResolve(ir.Struct s)
	{
		resolve(s.myScope.parent, s.userAttrs);
		s.isResolved = true;
		resolve(s.myScope, s.members);

	}

	override void doResolve(ir.Union u)
	{
		resolve(u.myScope.parent, u.userAttrs);
		u.isResolved = true;
		resolve(u.myScope, u.members);
	}

	override void doResolve(ir.Class c)
	{
		resolve(c.myScope.parent, c.userAttrs);
		fillInParentIfNeeded(this, c);
		c.isResolved = true;
		resolve(c.myScope, c.members);
	}

	override void doResolve(ir.UserAttribute ua)
	{
		// Nothing to do here.
		ua.isResolved = true;
	}


	/*
	 *
	 * Actualize functons.
	 *
	 */


	override void doActualize(ir.Struct s)
	{
		super.resolve(s);

		auto w = mTracker.add(s, "actualizing struct");
		scope (exit)
			w.done();

		actualizeStruct(this, s);
	}

	override void doActualize(ir.Union u)
	{
		super.resolve(u);

		auto w = mTracker.add(u, "actualizing union");
		scope (exit)
			w.done();

		actualizeUnion(this, u);
	}

	override void doActualize(ir.Class c)
	{
		super.resolve(c);

		auto w = mTracker.add(c, "actualizing class");
		scope (exit)
			w.done();

		actualizeClass(this, c);
	}

	override void doActualize(ir.UserAttribute ua)
	{
		super.resolve(ua);

		auto w = mTracker.add(ua, "actualizing user attribute");
		scope (exit)
			w.done();

		actualizeUserAttribute(this, ua);
	}


	/*
	 *
	 * Phase functions.
	 *
	 */


	override void phase1(ir.Module m)
	{
		if (m.hasPhase1)
			return;
		m.hasPhase1 = true;

		foreach(pass; postParse) {
			debugPrint("Phase 1 %s.", m.name);
			pass.transform(m);
		}

		if (settings.removeConditionalsOnly) {
			return;
		}

		// Need to create one for each import since,
		// the import resolver will cause phase1 to be called.
		auto impRes = new ImportResolver(this);
		impRes.transform(m);
	}

	override void phase2(ir.Module[] mods)
	{
		foreach(m; mods) {
			if (m.hasPhase2)
				continue;
			m.hasPhase2 = true;

			foreach(pass; passes2) {
				debugPrint("Phase 2 %s.", m.name);
				pass.transform(m);
			}
		}
	}

	override void phase3(ir.Module[] mods)
	{
		foreach(m; mods) {
			foreach(pass; passes3) {
				debugPrint("Phase 3 %s.", m.name);
				pass.transform(m);
			}
		}
	}

	override void close()
	{
		foreach(pass; postParse)
			pass.close();
		foreach(pass; passes2)
			pass.close();
		foreach(pass; passes3)
			pass.close();
	}


	/*
	 *
	 * Random stuff.
	 *
	 */


	private void resolve(ir.Scope current, ir.Attribute[] userAttrs)
	{
		foreach (a; userAttrs) {
			resolve(current, a);
		}
	}

	private void resolve(ir.Scope current, ir.TopLevelBlock members)
	{
		foreach (node; members.nodes) {
			auto var = cast(ir.Variable) node;
			if (var is null) {
				continue;
			}
			resolve(current, var);
		}
	}

	private void debugPrint(string msg, ir.QualifiedName name)
	{
		if (settings.internalDebug) {
			stdout.writefln(msg, name);
		}
	}
}
