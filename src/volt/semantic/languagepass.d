// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.languagepass;

import std.stdio : stdout;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;

import volt.token.location;

import volt.util.worktracker;

import volt.visitor.docprinter;
import volt.visitor.debugprinter;
import volt.visitor.prettyprinter;

import volt.lowerer.llvmlowerer;
import volt.lowerer.newreplacer;
import volt.lowerer.manglewriter;
import volt.lowerer.typeidreplacer;

import volt.semantic.cfg;
import volt.semantic.util;
import volt.semantic.ctfe;
import volt.semantic.lookup;
import volt.semantic.strace;
import volt.semantic.extyper;
import volt.semantic.typeinfo;
import volt.semantic.irverifier;
import volt.semantic.ctfe;
import volt.semantic.cfg;
import volt.semantic.storageremoval;

import volt.semantic.resolver;
import volt.semantic.classify;
import volt.semantic.irverifier;
import volt.semantic.classresolver;
import volt.semantic.aliasresolver;
import volt.semantic.userattrresolver;

import volt.postparse.gatherer;
import volt.postparse.condremoval;
import volt.postparse.attribremoval;
import volt.postparse.scopereplacer;
import volt.postparse.importresolver;


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
	this(Driver driver, Settings settings, Frontend frontend)
	{
		super(driver, settings, frontend);

		mTracker = new WorkTracker();

		postParse ~= new ConditionalRemoval(this);
		if (settings.removeConditionalsOnly) {
			return;
		}
		postParse ~= new ScopeReplacer();
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

	override void close()
	{
		foreach(pass; postParse)
			pass.close();
		foreach(pass; passes2)
			pass.close();
		foreach(pass; passes3)
			pass.close();
	}

	/**
	 * This functions sets up the pointers to the often used
	 * inbuilt classes, such as object.Object and object.TypeInfo.
	 * This needs to be called after the Driver is fully setup.
	 */
	void setupOneTruePointers()
	{
		objectModule =
			getModule(buildQualifiedName(Location(), "object"));
		if (objectModule is null) {
			throw panic("could not find object module");
		}


		// Run postParse passes so we can lookup things.
		phase1(objectModule);

		if (settings.removeConditionalsOnly) {
			return;
		}

		// The object module scope from which we should get everthing
		// from, setup this here for convinience.
		auto s = objectModule.myScope;

		void check(ir.Node n, string name)
		{
			if (n is null) {
				throw panicRuntimeObjectNotFound(name);
			}
		}

		ir.EnumDeclaration getEnum(string name)
		{
			auto ed = cast(ir.EnumDeclaration)s.getStore(name).node;
			check(ed, name);
			return ed;
		}

		ir.Class getClass(string name)
		{
			auto clazz = cast(ir.Class)s.getStore(name).node;
			check(clazz, name);
			return clazz;
		}

		ir.Function getFunction(string name)
		{
			auto fn = cast(ir.Function)s.getStore(name).node;
			check(fn, name);
			return fn;
		}

		ir.Variable getVar(string name)
		{
			auto var = cast(ir.Variable)s.getStore(name).node;
			check(var, name);
			return var;
		}

		ir.Struct getStruct(string name)
		{
			auto _struct = cast(ir.Struct)s.getStore(name).node;
			check(_struct, name);
			return _struct;
		}

		// Get the classes.
		objectClass = getClass("Object");
		typeInfoClass = getClass("TypeInfo");
		attributeClass = getClass("Attribute");
		assertErrorClass = getClass("AssertError");
		arrayStruct = getStruct("ArrayStruct");
		allocDgVariable = getVar("allocDg");

		// VA
		vaStartFunc = getFunction("__volt_va_start");
		vaEndFunc = getFunction("__volt_va_end");
		vaCStartFunc = getFunction("__llvm_volt_va_start");
		vaCEndFunc = getFunction("__llvm_volt_va_end");

		// Util
		hashFunc = getFunction("vrt_hash");
		castFunc = getFunction("vrt_handle_cast");
		printfFunc = getFunction("vrt_printf");
		memcpyFunc = getFunction("__llvm_memcpy_p0i8_p0i8_i32");
		memcmpFunc = getFunction("vrt_memcmp");

		// EH
		ehThrowFunc = getFunction("vrt_eh_throw");
		ehThrowSliceErrorFunc = getFunction("vrt_eh_throw_slice_error");
		ehPersonalityFunc = getFunction("vrt_eh_personality_v0");

		// AA
		aaGetKeys = getFunction("vrt_aa_get_keys");
		aaGetValues = getFunction("vrt_aa_get_values");
		aaGetLength = getFunction("vrt_aa_get_length");
		aaInArray = getFunction("vrt_aa_in_binop_array");
		aaInPrimitive = getFunction("vrt_aa_in_binop_primitive");
		aaRehash = getFunction("vrt_aa_rehash");
		aaGetPP = getFunction("vrt_aa_get_pp");
		aaGetAA = getFunction("vrt_aa_get_aa");
		aaGetAP = getFunction("vrt_aa_get_ap");
		aaGetPA = getFunction("vrt_aa_get_pa");
		aaDeletePrimitive = getFunction("vrt_aa_delete_primitive");
		aaDeleteArray = getFunction("vrt_aa_delete_array");
		aaDup = getFunction("vrt_aa_dup");

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

	override void addModule(ir.Module m)
	{
		auto str = m.name.toString();

		if (str in mModules) {
			throw makeAlreadyLoaded(m, m.location.filename);
		}

		mModules[str] = m;
	}

	override ir.Module getModule(ir.QualifiedName name)
	{
		auto str = name.toString();
		ir.Module m;

		auto p = str in mModules;
		if (p is null) {
			m = driver.loadModule(name);
			if (m is null) {
				return null;
			}
			mModules[str] = m;
		} else {
			m = *p;
		}

		// Need to make sure that this module can
		// be used by other modules.
		phase1(m);

		return m;
	}

	override ir.Module[] getModules()
	{
		return mModules.values.dup;
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

		tr.type = flattenStorage(lookupType(this, current, tr.id));
		tr.type.glossedName = tr.id.toString();
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

		v.type = flattenStorage(v.type);

		v.isResolved = true;
	}

	override void resolve(ir.Scope current, ir.Function fn)
	{
		if ((fn.kind == ir.Function.Kind.Function ||
		    (cast(ir.Class) fn.myScope.parent.node) is null) &&
		    fn.isMarkedOverride) {
			throw makeMarkedOverrideDoesNotOverride(fn, fn);
		}
		ensureResolved(this, current, fn.type);
		replaceVarArgsIfNeeded(this, fn);
		foreach (i, ref param; fn.params) {
			fn.type.params[i] = flattenStorage(fn.type.params[i], fn.type, i);
			if (param.assign !is null) {
				auto texp = cast(ir.TokenExp) param.assign;
				if (texp is null) {
					param.assign = evaluate(
						this, current, param.assign);
				}
			}
		}
		fn.type.ret = flattenStorage(fn.type.ret);
		resolve(current, fn.userAttrs);
	}

	override void resolve(ir.Scope current, ir.ExpReference eref)
	{
		auto var = cast(ir.Variable) eref.decl;
		if (var !is null) {
			resolve(current, var);
			return;
		}
		auto fn = cast(ir.Function) eref.decl;
		if (fn !is null) {
			resolve(current, fn);
			return;
		}
		auto set = cast(ir.FunctionSet) eref.decl;
		if (set !is null) {
			foreach (setfn; set.functions) {
				resolve(current, setfn);
			}
			return;
		}
		auto fparam = cast(ir.FunctionParam) eref.decl;
		if (set !is null) {
			fparam.fn.type.params[fparam.index] = flattenStorage(fparam.fn.type.params[fparam.index]);
			return;
		}
		auto edecl = cast(ir.EnumDeclaration) eref.decl;
		if (edecl !is null) {
			edecl.type = flattenStorage(edecl.type);
		}
	}

	override void resolve(ir.Alias a)
	{
		if (!a.resolved) {
			resolve(a.store);
		}
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

	override void resolve(ir.Scope current, ir.EnumDeclaration ed)
	{
		if (ed.resolved) {
			return;
		}

		ed.type = flattenStorage(ed.type);
		auto e = new ExTyper(this);
		e.transform(current, ed);
	}

	override void resolve(ir.Scope current, ir.AAType at)
	{
		ensureResolved(this, current, at.value);
		ensureResolved(this, current, at.key);
		at.key = flattenStorage(at.key);
		at.value = flattenStorage(at.value);

		auto base = at.key;

		auto tr = cast(ir.TypeReference)base;
		if (tr !is null) {
			base = tr.type;
		}

		if (base.nodeType() == ir.NodeType.Struct ||
		    base.nodeType() == ir.NodeType.Class) {
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


	/*
	 *
	 * DoResolve functions.
	 *
	 */

	override void doResolve(ir.Enum e)
	{
		e.base = flattenStorage(e.base);
		resolveEnum(this, e);
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

	override void doResolve(ir._Interface i)
	{
		i.isResolved = true;
	}

	override void doResolve(ir.UserAttribute ua)
	{
		// Nothing to do here.
		ua.isResolved = true;
	}


	/*
	 *
	 * Actualize functions.
	 *
	 */

	override void doActualize(ir._Interface i)
	{
		resolveNamed(i);

		auto w = mTracker.add(i, "actualizing interface");
		scope (exit)
			w.done();

		actualizeInterface(this, i);
	}

	override void doActualize(ir.Struct s)
	{
		resolveNamed(s);

		auto w = mTracker.add(s, "actualizing struct");
		scope (exit)
			w.done();

		actualizeStruct(this, s);
	}

	override void doActualize(ir.Union u)
	{
		resolveNamed(u);

		auto w = mTracker.add(u, "actualizing union");
		scope (exit)
			w.done();

		actualizeUnion(this, u);
	}

	override void doActualize(ir.Class c)
	{
		resolveNamed(c);

		auto w = mTracker.add(c, "actualizing class");
		scope (exit)
			w.done();

		actualizeClass(this, c);
	}

	override void doActualize(ir.UserAttribute ua)
	{
		resolveNamed(ua);

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


	final void phase1(ir.Module m)
	{
		if (m.hasPhase1) {
			return;
		}
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

	final void phase2(ir.Module m)
	{
		if (m.hasPhase2) {
			return;
		}
		m.hasPhase2 = true;

		foreach(pass; passes2) {
			debugPrint("Phase 2 %s.", m.name);
			pass.transform(m);
		}
	}

	final void phase3(ir.Module m)
	{
		foreach(pass; passes3) {
			debugPrint("Phase 3 %s.", m.name);
			pass.transform(m);
		}
	}

	override void phase1(ir.Module[] ms) { foreach(m; ms) { phase1(m); } }
	override void phase2(ir.Module[] ms) { foreach(m; ms) { phase2(m); } }
	override void phase3(ir.Module[] ms) { foreach(m; ms) { phase3(m); } }


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
