/*#D*/
// Copyright © 2012-2017, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.languagepass;

import watt.io.std : output;
import watt.text.format : format;

import ir = volta.ir;
import pp = volta.postparse.pass;

import volta.util.util;
import volta.util.dup;

import volt.errors;
import volt.interfaces;
import volta.settings;
import volta.ir.location;

import volt.util.perf;
import volt.util.worktracker;

import volt.visitor.debugprinter;
import volt.visitor.prettyprinter;

import volt.lowerer.image;
import volt.lowerer.llvmlowerer;
import volt.lowerer.newreplacer;
import volt.lowerer.manglewriter;
import volt.lowerer.typeidreplacer;

import volt.semantic.cfg;
import volt.semantic.util;
import volt.semantic.folder;
import volt.semantic.lifter;
import volt.semantic.lookup;
import volt.semantic.extyper;
import volt.semantic.evaluate;
import volt.semantic.classify;
import volt.semantic.typeinfo;
import volt.semantic.irverifier;
import volt.semantic.classresolver;

import volta.postparse.pass;
import volta.postparse.gatherer;

enum Mode
{
	Normal,
	RemoveConditionalsOnly,
	MissingDeps,
}

/*!
 * Default implementation of
 * @link volt.interfaces.LanguagePass LanguagePass@endlink, replace
 * this if you wish to any of the semantics of the language.
 *
 * @ingroup semantic passes passLang passSem
 */
class VoltLanguagePass : LanguagePass
{
public:
	/*!
	 * Phases fields.
	 * @{
	 */
	Pass[] passes1;
	Pass[] passes2;
	Pass[] passes3;
	/*!
	 * @}
	 */

	PostParseImpl postParseImpl;


private:
	Mode mMode;
	bool mRemoveConditionalsOnly;
	WorkTracker mTracker;
	ir.Module[string] mModules;

	static class TimerPass : Pass
	{
		Pass mPass;
		Accumulator mAccum;

		this(string name, Pass pass)
		{
			this.mPass = pass;
			this.mAccum = new Accumulator(name);
		}

		override void transform(ir.Module m)
		{
			mAccum.start();
			scope (exit) mAccum.stop();
			mPass.transform(m);
		}

		override void close()
		{
			mPass.close();
		}
	}


public:
	this(ErrorSink err, Driver drv, VersionSet ver, TargetInfo target,
	     Settings settings, Frontend frontend, Mode mode, bool warnings)
	{
		this.settings = settings;
		this.warningsEnabled = warnings;
		this.mMode = mode;
		super(err, drv, ver, target, frontend);

		mTracker = new WorkTracker();

		version (D_Version2) auto getMod = &this.getModule;
		else auto getMod = this.getModule;

		postParse = postParseImpl = new pp.PostParseImpl(
			err, ver, target, warningsEnabled,
			mMode == Mode.RemoveConditionalsOnly,
			mMode == Mode.MissingDeps,
			getMod);
		passes1 ~= new TimerPass("pp", postParseImpl);
		if (mMode == Mode.RemoveConditionalsOnly) {
			return;
		}

		passes2 ~= new TimerPass("p2-extyper", new ExTyper(this));
		passes2 ~= new TimerPass("p2-cfgbuilder", new CFGBuilder(this));
		debug passes2 ~= new TimerPass("p2-irverifier", new IrVerifier(errSink));

		passes3 ~= new TimerPass("p3-expfolder", new ExpFolder(target));
		passes3 ~= new TimerPass("p3-llvm", new LlvmLowerer(this));
		passes3 ~= new TimerPass("p3-new-rep", new NewReplacer(this));
		passes3 ~= new TimerPass("p3-typeid-rep", new TypeidReplacer(this));
		passes3 ~= new TimerPass("p3-image", new ImageGatherer(this));
		passes3 ~= new TimerPass("p3-mangle-writer", new MangleWriter());
		debug passes3 ~= new TimerPass("p3-irverifier", new IrVerifier(errSink));
	}

	override void close()
	{
		foreach (pass; passes1) {
			pass.close();
		}
		foreach (pass; passes2) {
			pass.close();
		}
		foreach (pass; passes3) {
			pass.close();
		}
	}

	/*!
	 * This functions sets up the pointers to the often used
	 * inbuilt classes, such as object.Object and object.TypeInfo.
	 * This needs to be called after the Driver is fully setup.
	 */
	void setupOneTruePointers()
	{
		auto objectModule = getAndCheck("core", "object");
		auto typeInfoModule = getAndCheck("core", "typeinfo");
		auto exceptionModule = getAndCheck("core", "exception");
		auto rtEHModule = getAndCheck("core", "rt", "eh");
		auto rtGCModule = getAndCheck("core", "rt", "gc");
		auto rtAAModule = getAndCheck("core", "rt", "aa");
		auto rtMiscModule = getAndCheck("core", "rt", "misc");
		auto rtFormatModule = getAndCheck("core", "rt", "format");
		auto llvmModule = getAndCheck("core", "compiler", "llvm");
		auto defModule = getAndCheck("core", "compiler", "defaultsymbols");
		auto varargsModule = getAndCheck("core", "varargs");

		ir.Module[] mods = [
			defModule,
			objectModule,
			typeInfoModule,
			exceptionModule,
			rtEHModule,
			rtGCModule,
			rtAAModule,
			rtMiscModule,
			rtFormatModule,
			llvmModule,
			varargsModule,
		];

		// Run postParse passes so we can lookup things.
		phase1(mods);

		if (mRemoveConditionalsOnly) {
			return;
		}

		int getEnumDeclarationValue(ir.Module mod, ir.EnumDeclaration ed)
		{
			assert(ed.assign !is null);
			auto constant = evaluate(this, mod.myScope, ed.assign);
			assert(constant !is null);
			return constant.u._int;
		}

		/*!
		 * Get a member from the Type enum.
		 */
		int getTypeEnum(string name)
		{
			auto e = cast(ir.Enum)getNodeFrom(typeInfoModule, "Type");
			check(e, "Type");
			foreach (ed; e.members) {
				if (ed.assign !is null && ed.name == name) {
					return getEnumDeclarationValue(typeInfoModule, ed);
				}
			}
			throw panicRuntimeObjectNotFound(name);
		}

		// core.object
		objObject = getClassFrom(objectModule, "Object");
		objObject.isObject = true;

		// core.varargs
		vaStartFunc = getFunctionFrom(varargsModule, "va_start");
		vaEndFunc = getFunctionFrom(varargsModule, "va_end");

		// core.typeinfo
		tiTypeInfo = getClassFrom(typeInfoModule, "TypeInfo");
		tiClassInfo = getClassFrom(typeInfoModule, "ClassInfo");
		tiInterfaceInfo = getClassFrom(typeInfoModule, "InterfaceInfo");
		TYPE_STRUCT = getTypeEnum("Struct");
		TYPE_CLASS = getTypeEnum("Class");
		TYPE_INTERFACE = getTypeEnum("Interface");
		TYPE_UNION = getTypeEnum("Union");
		TYPE_ENUM = getTypeEnum("Enum");
		TYPE_ATTRIBUTE = getTypeEnum("Attribute");
		TYPE_VOID = getTypeEnum("Void");
		TYPE_UBYTE = getTypeEnum("U8");
		TYPE_BYTE = getTypeEnum("I8");
		TYPE_CHAR = getTypeEnum("Char");
		TYPE_BOOL = getTypeEnum("Bool");
		TYPE_USHORT = getTypeEnum("U16");
		TYPE_SHORT = getTypeEnum("I16");
		TYPE_WCHAR = getTypeEnum("Wchar");
		TYPE_UINT = getTypeEnum("U32");
		TYPE_INT = getTypeEnum("I32");
		TYPE_DCHAR = getTypeEnum("Dchar");
		TYPE_FLOAT = getTypeEnum("F32");
		TYPE_ULONG = getTypeEnum("U64");
		TYPE_LONG = getTypeEnum("I64");
		TYPE_DOUBLE = getTypeEnum("F64");
		TYPE_REAL = getTypeEnum("Real");
		TYPE_POINTER = getTypeEnum("Pointer");
		TYPE_ARRAY = getTypeEnum("Array");
		TYPE_STATIC_ARRAY = getTypeEnum("StaticArray");
		TYPE_AA = getTypeEnum("AA");
		TYPE_FUNCTION = getTypeEnum("Function");
		TYPE_DELEGATE = getTypeEnum("Delegate");

		// core.exception
		exceptThrowable = getClassFrom(exceptionModule, "Throwable");

		// core.rt.eh
		ehThrowFunc = getFunctionFrom(rtEHModule, "vrt_eh_throw");
		ehThrowSliceErrorFunc = getFunctionFrom(rtEHModule, "vrt_eh_throw_slice_error");
		ehThrowAssertErrorFunc = getFunctionFrom(rtEHModule, "vrt_eh_throw_assert_error");
		ehThrowKeyNotFoundErrorFunc = getFunctionFrom(rtEHModule, "vrt_eh_throw_key_not_found_error");
		ehPersonalityFunc = getFunctionFrom(rtEHModule, "vrt_eh_personality_v0");

		// core.rt.gc
		gcAllocDgVariable = getVarFrom(rtGCModule, "allocDg");

		// core.rt.aa
		aaNew = getFunctionFrom(rtAAModule, "vrt_aa_new");
		aaDup = getFunctionFrom(rtAAModule, "vrt_aa_dup");
		aaRehash = getFunctionFrom(rtAAModule, "vrt_aa_rehash");
		aaGetKeys = getFunctionFrom(rtAAModule, "vrt_aa_get_keys");
		aaGetValues = getFunctionFrom(rtAAModule, "vrt_aa_get_values");
		aaGetLength = getFunctionFrom(rtAAModule, "vrt_aa_get_length");
		aaInsertPrimitive = getFunctionFrom(rtAAModule, "vrt_aa_insert_primitive");
		aaInsertArray = getFunctionFrom(rtAAModule, "vrt_aa_insert_array");
		aaInsertPtr = getFunctionFrom(rtAAModule, "vrt_aa_insert_ptr");
		aaDeletePrimitive = getFunctionFrom(rtAAModule, "vrt_aa_delete_primitive");
		aaDeleteArray = getFunctionFrom(rtAAModule, "vrt_aa_delete_array");
		aaDeletePtr = getFunctionFrom(rtAAModule, "vrt_aa_delete_ptr");
		aaInPrimitive = getFunctionFrom(rtAAModule, "vrt_aa_in_primitive");
		aaInArray = getFunctionFrom(rtAAModule, "vrt_aa_in_array");
		aaInPtr = getFunctionFrom(rtAAModule, "vrt_aa_in_ptr");
		aaInBinopPrimitive = getFunctionFrom(rtAAModule, "vrt_aa_in_binop_primitive");
		aaInBinopArray = getFunctionFrom(rtAAModule, "vrt_aa_in_binop_array");
		aaInBinopPtr = getFunctionFrom(rtAAModule, "vrt_aa_in_binop_ptr");

		// core.rt.misc
		utfDecode_u8_d = getFunctionFrom(rtMiscModule, "vrt_decode_u8_d");
		utfReverseDecode_u8_d = getFunctionFrom(rtMiscModule, "vrt_reverse_decode_u8_d");
		hashFunc = getFunctionFrom(rtMiscModule, "vrt_hash");
		castFunc = getFunctionFrom(rtMiscModule, "vrt_handle_cast");
		memcmpFunc = getFunctionFrom(rtMiscModule, "vrt_memcmp");
		runMainFunc = getFunctionFrom(rtMiscModule, "vrt_run_main");

		// core.compiler.llvm
		llvmTypeidFor = getFunctionFrom(llvmModule, "__llvm_typeid_for");
		llvmMemmove32 = getFunctionFrom(llvmModule, "__llvm_memmove_p0i8_p0i8_i32");
		llvmMemmove64 = getFunctionFrom(llvmModule, "__llvm_memmove_p0i8_p0i8_i64");
		llvmMemcpy32 = getFunctionFrom(llvmModule, "__llvm_memcpy_p0i8_p0i8_i32");
		llvmMemcpy64 = getFunctionFrom(llvmModule, "__llvm_memcpy_p0i8_p0i8_i64");
		llvmMemset32 = getFunctionFrom(llvmModule, "__llvm_memset_p0i8_i32");
		llvmMemset64 = getFunctionFrom(llvmModule, "__llvm_memset_p0i8_i64");

		sinkType = getAliasFrom(rtFormatModule, "Sink");
		sinkStore = getAliasFrom(rtFormatModule, "SinkStore1024");
		sinkInit = getFunctionFrom(rtFormatModule, "vrt_sink_init_1024");
		sinkGetStr = getFunctionFrom(rtFormatModule, "vrt_sink_getstr_1024");
		formatHex = getFunctionFrom(rtFormatModule, "vrt_format_hex");
		formatI64 = getFunctionFrom(rtFormatModule, "vrt_format_i64");
		formatU64 = getFunctionFrom(rtFormatModule, "vrt_format_u64");
		formatF32 = getFunctionFrom(rtFormatModule, "vrt_format_f32");
		formatF64 = getFunctionFrom(rtFormatModule, "vrt_format_f64");
		formatDchar = getFunctionFrom(rtFormatModule, "vrt_format_dchar");

		phase2(mods);
	}

	override void addModule(ir.Module m)
	{
		auto str = m.name.toString();

		if (str in mModules) {
			throw makeAlreadyLoaded(m, m.loc.filename);
		}

		mModules[str] = m;
	}

	override ir.Module getModule(ir.QualifiedName name)
	{
		auto str = name.toString();

		auto p = str in mModules;
		if (p !is null) {
			return *p;
		}

		auto m = driver.loadModule(name);
		if (m is null) {
			return null;
		}
		mModules[str] = m;
		return m;
	}

	override ir.Module[] getModules()
	{
		return mModules.values.dup();
	}

	/*
	 *
	 * Circular dependancy checker.
	 *
	 */

	override DoneDg startResolving(ir.Node n)
	{
		version (Volt) {
			return mTracker.add(n, Work.Action.Resolve).done;
		} else {
			return &mTracker.add(n, Work.Action.Resolve).done;
		}
	}

	override DoneDg startActualizing(ir.Node n)
	{
		version (Volt) {
			return mTracker.add(n, Work.Action.Actualize).done;
		} else {
			return &mTracker.add(n, Work.Action.Actualize).done;
		}
	}


	/*
	 *
	 * Resolver functions.
	 *
	 */

	override void resolve(ir.Scope current, ir.Attribute[] userAttrs)
	{
		foreach (a; userAttrs) {
			resolve(current, a);
		}
	}

	override void resolve(ir.Scope current, ir.ExpReference eref)
	{
		auto var = cast(ir.Variable) eref.decl;
		if (var !is null) {
			// This is not correct scope.
			debug if (!var.isResolved) {
				debugPrintNode(eref);
				panicAssert(eref, false);
			}
			return;
		}
		auto func = cast(ir.Function) eref.decl;
		if (func !is null) {
			// This is not correct scope.
			debug if (!func.isResolved) {
				debugPrintNode(eref);
				panicAssert(eref, false);
			}
			return;
		}
		auto set = cast(ir.FunctionSet) eref.decl;
		if (set !is null) {
			debug foreach (setfn; set.functions) {
				if (!setfn.isResolved) {
					debugPrintNode(eref);
					panicAssert(eref, false);
				}
			}
			return;
		}
	}

	override void resolve(ir.Scope current, ir.Attribute a)
	{
		//if (!needsResolving(a)) {
		//	return;
		//}

		auto e = new ExTyper(this);
		e.transform(current, a);
	}

	override void resolve(ir.Scope current, ir.TemplateInstance ti)
	{
		auto e = new ExTyper(this);
		e.transform(current, ti);
	}

	override void resolve(ir.Scope current, ir.EnumDeclaration ed)
	{
		if (ed.resolved) {
			return;
		}

		auto e = new ExTyper(this);
		e.transform(current, ed);
	}

	override void resolve(ir.Store s)
	{
		assert(s.kind == ir.Store.Kind.Merge);
		assert(s.aliases.length > 0);

		// Can't use Resolve action since we will resolve the alias soon.
		auto w = mTracker.add(s.aliases[0], Work.Action.Actualize);
		scope (exit) {
			w.done();
		}

		// Using aliases you can by accident include the same function
		// multiple times in a single Merge store, so avoid that using
		// the uniqueId of the Function node.
		ir.Function[ir.NodeID] store;

		foreach (func; s.functions) {
			assert(s.parent is func.myScope.parent);
			super.resolve(func.myScope.parent, func);
			store[func.uniqueId] = func;
		}

		foreach (a; s.aliases) {
			auto r = ensureResolved(this, a.store);
			if (r.kind != ir.Store.Kind.Function) {
				throw makeBadMerge(a, s);
			}

			foreach (func; r.functions) {
				store[func.uniqueId] = func;
			}
		}

		s.functions = store.values;
		s.aliases = null;
		s.kind = ir.Store.Kind.Function;
	}


	/*
	 *
	 * DoResolve functions.
	 *
	 */

protected:
	override void doResolve(ir.Scope current, ir.Variable v)
	{
		auto e = new ExTyper(this);
		e.resolve(current, v);
	}

	override void doResolve(ir.Scope current, ir.Function func)
	{
		auto e = new ExTyper(this);
		e.resolve(current, func);
	}

	override void doResolve(ir.Alias a)
	{
		panicAssert(a, a.store !is null);
		panicAssert(a, a.store.node is a);

		auto w = mTracker.add(a, Work.Action.Resolve);
		scope (exit) {
			w.done();
		}

		resolveAlias(this, a);
	}

	override void doResolve(ir.Enum e)
	{
		resolveEnum(this, e);
	}

	override void doResolve(ir.Struct s)
	{
		resolveStruct(this, s);
	}

	override void doResolve(ir.Union u)
	{
		resolveUnion(this, u);
	}

	override void doResolve(ir.Class c)
	{
		fillInParentIfNeeded(this, c);
		fillInInterfacesIfNeeded(this, c);
		c.isResolved = true;
		resolve(c.myScope, c.members);
	}

	override void doResolve(ir._Interface i)
	{
		i.isResolved = true;
	}

	/*
	 *
	 * Actualize functions.
	 *
	 */

	override void doActualize(ir._Interface i)
	{
		resolveNamed(i);

		auto w = mTracker.add(i, Work.Action.Actualize);
		scope (exit) {
			w.done();
		}

		actualizeInterface(this, i);
	}

	override void doActualize(ir.Struct s)
	{
		assert(!s.isResolved);
		resolveStruct(this, s);

		auto w = mTracker.add(s, Work.Action.Actualize);
		scope (exit) {
			w.done();
		}
		addPODConstructors(s);
	}

	override void doActualize(ir.Union u)
	{
		assert(!u.isResolved);
		resolveUnion(this, u);

		auto w = mTracker.add(u, Work.Action.Actualize);
		scope (exit) {
			w.done();
		}
		addPODConstructors(u);
	}

	override void doActualize(ir.Class c)
	{
		resolveNamed(c);

		auto w = mTracker.add(c, Work.Action.Actualize);
		scope (exit) {
			w.done();
		}

		actualizeClass(this, c);
	}

public:
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

		debugPrint("Phase 1 %s.", m.name);
		foreach (pass; passes1) {
			pass.transform(m);
		}
		debugPrint("Phase 1 %s done.", m.name);
	}

	final void phase2(ir.Module m)
	{
		if (m.hasPhase2) {
			return;
		}
		m.hasPhase2 = true;

		debugPrint("Phase 2 %s.", m.name);
		foreach (pass; passes2) {
			pass.transform(m);
		}
		debugPrint("Phase 2 %s done.", m.name);
	}

	final void phase3(ir.Module m)
	{
		debugPrint("Phase 3 %s.", m.name);
		foreach (pass; passes3) {
			pass.transform(m);
		}
		debugPrint("Phase 3 %s done.", m.name);
	}

	override void phase1(ir.Module[] ms) { foreach (m; ms) { phase1(m); } }
	override void phase2(ir.Module[] ms) { foreach (m; ms) { phase2(m); } }
	override void phase3(ir.Module[] ms) { foreach (m; ms) { phase3(m); } }


	/*
	 *
	 * Random stuff.
	 *
	 */

	private ir.Module getAndCheck(string[] names...)
	{
		Location loc;
		auto id = buildQualifiedName(/*#ref*/loc, names);
		auto m = getModule(id);
		if (m is null) {
			throw panic(format("Could not find module %s", id.toString()));
		}
		return m;
	}

	private static void check(ir.Node n, string name)
	{
		if (n is null) {
			throw panicRuntimeObjectNotFound(name);
		}
	}

	private static ir.Node getNodeFrom(ir.Module mod, string name)
	{
		auto s = mod.myScope.getStore(name);
		return s !is null ? s.node : null;
	}

	private static ir.Type getAliasFrom(ir.Module mod, string name)
	{
		auto tr = cast(ir.Alias)getNodeFrom(mod, name);
		auto typ = tr.type;
		if (typ.nodeType == ir.NodeType.StorageType) {
			auto st = typ.toStorageTypeFast();
			typ = st.base;
		}
		check(typ, name);
		return typ;
	}

	private static ir.Class getClassFrom(ir.Module mod, string name)
	{
		auto clazz = cast(ir.Class)getNodeFrom(mod, name);
		check(clazz, name);
		return clazz;
	}

	private static ir.Variable getVarFrom(ir.Module mod, string name)
	{
		auto var = cast(ir.Variable)getNodeFrom(mod, name);
		check(var, name);
		return var;
	}

	private static ir.Struct getStructFrom(ir.Module mod, string name)
	{
		auto _struct = cast(ir.Struct)getNodeFrom(mod, name);
		check(_struct, name);
		return _struct;
	}

	private static ir.Function getFunctionFrom(ir.Module mod, string name)
	{
		auto func = cast(ir.Function)getNodeFrom(mod, name);
		check(func, name);
		return func;
	}

	private void addPODConstructors(ir.PODAggregate agg)
	{
		foreach (node; agg.members.nodes) {
			auto func = cast(ir.Function)node;
			if (func is null ||
			    func.kind != ir.Function.Kind.Constructor) {
				continue;
			}
			agg.constructors ~= func;
		}
	}

	void resolve(ir.Scope current, ir.TopLevelBlock members)
	{
		foreach (node; members.nodes) {
			auto var = cast(ir.Variable) node;
			if (var is null || var.isResolved) {
				continue;
			}
			doResolve(current, var);
		}
	}

	private void debugPrint(string msg, ir.QualifiedName name)
	{
		if (driver.internalDebug) {
			output.writefln(msg, name);
		}
	}
}
