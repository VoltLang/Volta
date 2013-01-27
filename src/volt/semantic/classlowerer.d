// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classlowerer;

import std.array : insertInPlace;
import std.conv : to;
import std.stdio;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.expreplace;
import volt.visitor.visitor;
import volt.semantic.classify;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.newreplacer;
import volt.token.location;


class ClassLowerer : NullExpReplaceVisitor, Pass
{
public:
	ir.Scope internalScope;
	ir.TopLevelBlock internalTLB;
	ir.Struct[ir.Class] synthesised;
	string[] parentNames;
	int passNumber;
	Settings settings;
	ir.Variable allocDgVar;
	ir.Scope currentFunctionScope;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

	/**
	 * The basic form of the constructor is as follows:
	 * ---
	 * Object* __ctor(int arg1, int arg2)
	 * {
	 *     Object* obj = cast(Object*) malloc(Object.sizeof);
	 *     obj.__vtable = cast(Object.__Vtable*) malloc(Object.__Vtable);
	 *     obj.__vtable._0 = firstMethod;
	 *     obj.__vtable._1 = secondMethod;
	 *     obj.__user_ctor(arg1, arg2, obj);
	 *     return obj;
	 * }
	 * ---
	 */
	ir.Function createConstructor(ir.Struct c, ir.Struct vtable, ir.Function[] userConstructors, ir.Variable vtableGlobal)
	{
		/* Okay, this might look kind of terrifying, but it's not too
		 * bad once you realise it's just a lot of setting up the artificial
		 * IR nodes. There's nothing complex going on here.
		 */

		// Object* obj
		auto objVar = new ir.Variable();
		objVar.location = c.location;
		objVar.type = new ir.PointerType(new ir.TypeReference(c, c.name));
		objVar.name = "obj";

		// Object* __ctor() { ... }
		auto fn = new ir.Function();
		fn.location = c.location;
		fn.name = "__ctor";
		fn._body = new ir.BlockStatement();
		fn._body.location = c.location;
		fn.defined = true;

		fn.type = new ir.FunctionType();
		fn.type.location = c.location;
		fn.type.ret = copyTypeSmart(c.location, objVar.type);

		if (userConstructors.length > 0) {
			assert(userConstructors.length == 1);

			foreach (param; userConstructors[0].type.params) {
				fn.type.params ~= new ir.Variable();
				fn.type.params[$-1].location = c.location;
				fn.type.params[$-1].name = param.name;
				fn.type.params[$-1].type = copyTypeSmart(c.location, param.type);
			}
		}

		fn.myScope = new ir.Scope(c.myScope, c, fn.name);

		// Object.sizeof
		int sz = size(c.location, settings, c);
		auto objSizeof = buildSizeTConstant(c.location, settings, sz);

		// cast(Object*) malloc(Object.sizeof);
		auto castExp = createAllocDgCall(allocDgVar, settings, c.location, new ir.TypeReference(c, c.name));

		objVar.assign = castExp;
		fn._body.statements ~= objVar;

		{
			auto objRef = buildExpReference(c.location, objVar, "obj");
			auto vtableGet = buildAddrOf(c.location, vtableGlobal, vtableGlobal.name);

			auto vtableAccess = new ir.Postfix();
			vtableAccess.location = c.location;
			vtableAccess.op = ir.Postfix.Op.Identifier;
			vtableAccess.identifier = new ir.Identifier();
			vtableAccess.identifier.location = c.location;
			vtableAccess.identifier.value = "__vtable";
			vtableAccess.child = objRef;

			auto vtableAssign = new ir.BinOp();
			vtableAssign.location = c.location;
			vtableAssign.op = ir.BinOp.Type.Assign;
			vtableAssign.left = vtableAccess;
			vtableAssign.right = vtableGet;

			auto expStatement = new ir.ExpStatement();
			expStatement.location = c.location;
			expStatement.exp = vtableAssign;
			fn._body.statements ~= expStatement;
		}

		// obj.__user_ctor(arg1, arg2, obj);
		if (userConstructors.length > 0) {
			auto objRef = new ir.ExpReference();
			objRef.location = c.location;
			objRef.decl = objVar;
			objRef.idents ~= "obj";

			auto uctor = new ir.ExpReference();
			uctor.location = c.location;
			uctor.idents ~= "__user_ctor";//userConstructors[0].name;
			uctor.decl = userConstructors[0];

			ir.Exp[] args;
			foreach (param; fn.type.params) {
				auto exp = new ir.ExpReference();
				exp.location = param.location;
				exp.idents ~= param.name;
				exp.decl = param;
				args ~= exp;
			}

			auto objCast = new ir.Unary(new ir.PointerType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Void)), objRef);
			args ~= objCast;

			auto uctorCall = new ir.Postfix();
			uctorCall.location = c.location;
			uctorCall.op = ir.Postfix.Op.Call;
			uctorCall.child = uctor;
			uctorCall.arguments = args;

			auto uctorCallStatement = new ir.ExpStatement();
			uctorCallStatement.location = c.location;
			uctorCallStatement.exp = uctorCall;
			fn._body.statements ~= uctorCallStatement;
		}

		// return obj;
		{
			auto objRef = new ir.ExpReference();
			objRef.location = c.location;
			objRef.decl = objVar;
			objRef.idents ~= "obj";

			auto retstatement = new ir.ReturnStatement();
			retstatement.location = c.location;
			retstatement.exp = objRef;
			fn._body.statements ~= retstatement;
		}

		return fn;
	}

public:
	/**
	 * Create a vtable struct for a given class.
	 *
	 * A vtable struct is a struct with function pointers
	 * of the class methods on it.
	 */
	ir.Struct createVtableStruct(Location location, ir.Struct parent, ir.Function[] functions)
	{
		auto _struct = buildStruct(location, parent.members, parent.myScope, "__Vtable");
		_struct.defined = true;

		foreach (i, _function; functions) {
			auto var = new ir.Variable();
			var.location = _struct.location;
			var.name = format("_%s", i);
			var.type = copyTypeSmart(_struct.location, _function.type);
			_struct.members.nodes ~= var;
		}

		return _struct;
	}

	/**
	 * For a given class, get return its inheritance chain.
	 *
	 * From child to parent.
	 *
	 * So
	 * ---
	 * class Child {}
	 * ---
	 * Returns [Child, Object].
	 */
	ir.Class[] getInheritanceChain(ir.Class _class)
	out(result)
	{
		assert(result.length >= 1);
	}
	body
	{
		ir.Class[] classChain;
		ir.Class currentClass = _class;
		while (currentClass !is null) {
			classChain ~= currentClass;
			currentClass = currentClass.parentClass;
		}
		return classChain;
	}

	/// Get the constructors from the head of the inheritance chain.
	ir.Function[] getConstructors(ir.Class[] inheritanceChain)
	{
		ir.Function[] constructors;
		foreach (node; inheritanceChain[0].members.nodes) {
			auto asFunction = cast(ir.Function) node;
			if (asFunction is null) {
				continue;
			}
			if (asFunction.kind != ir.Function.Kind.Constructor) {
				continue;
			}
			constructors ~= asFunction;
		}
		return constructors;
	}

	/**
	 * Retrieve all appropriate methods for a given inheritance chain,
	 * taking into account function overriding.
	 *
	 * Side-effects: change the type of the hidden this to the struct.
	 */
	ir.Function[] getMethods(ir.Class[] inheritanceChain, ir.Struct _struct, out ir.Function[] myMethods)
	{
		ir.Function[] methods;
		int[string] definedMethods;

		for (int i = cast(int)(inheritanceChain.length - 1); i >= 0; --i) {
			auto _class = inheritanceChain[i];
			int methodsAdded;
			foreach (node; _class.members.nodes) {
				if (node.nodeType != ir.NodeType.Function) {
					continue;
				}
				auto asFunction = cast(ir.Function) node;
				assert(asFunction !is null);

				if (asFunction.thisHiddenParameter is null) {
					continue;
				}

				auto asTypeRef = cast(ir.TypeReference) asFunction.thisHiddenParameter.type;
				assert(asTypeRef !is null);

				auto asClass = cast(ir.Class) asTypeRef.type;
				if (asClass !is null) {
					asTypeRef.type = _struct;
					asFunction.myScope.parent = _struct.myScope;
				}

				// Don't add constructors to the method list.
				if (asFunction.kind == ir.Function.Kind.Constructor) {
					continue;
				}

				// And test again...
				if (asClass !is null) {
					asFunction.vtableIndex = methodsAdded++;
					myMethods ~= asFunction;
					assert(asFunction.type.hiddenParameter);
				}

				if (auto indexPointer = asFunction.name in definedMethods) {
					methods[*indexPointer] = asFunction;
				} else {
					methods ~= asFunction;
					definedMethods[asFunction.name] = cast(int)methods.length - 1;
				}
			}
		}
		return methods;
	}

	/**
	 * Retrieve all appropriate fields for a given inheritance chain.
	 */
	ir.Variable[] getFields(ir.Class[] inheritanceChain)
	{
		ir.Variable[] fields;
		for (int i = cast(int)(inheritanceChain.length - 1); i >= 0; --i) {
			auto _class = inheritanceChain[i];
			foreach (node; _class.members.nodes) {
				auto asVar = cast(ir.Variable) node;
				if (asVar !is null) {
					fields ~= asVar;
				}
			}
		}
		return fields;
	}

	/**
	 * If _class has been previously converted into a lowered struct, return that.
	 * Otherwise, turn class into a struct.
	 */
	ir.Struct createClassStruct(ir.Class _class)
	{
		// If we have already created this class struct, return it.
		string name = mangle(parentNames, _class);
		assert(name != "");
		if (auto oldStruct = _class in synthesised) {
			return *oldStruct;
		}

		// Create the empty struct for us to work with.
		auto _struct = new ir.Struct();
		_struct.name = _class.name;
		_struct.location = _class.location;
		_struct.myScope = new ir.Scope(_class.myScope.parent, _struct, _class.name);
		_struct.members = new ir.TopLevelBlock();
		_struct.members.location = _class.location;
		_struct.mangledName = name;
		_struct.loweredNode = _class;
		synthesised[_class] = _struct;

		// Retrieve the methods and fields for this class.
		ir.Function[] myMethods;
		auto inheritanceChain = getInheritanceChain(_class);
		auto methods = getMethods(inheritanceChain, _struct, myMethods);
		auto fields = getFields(inheritanceChain);
		auto constructors = getConstructors(inheritanceChain);

		/// @todo When we have function overloading, allow multiple constructors.
		if (constructors.length > 1) {
			throw CompilerPanic(_class.location, "multiple constructors not supported.");
		}
		_class.userConstructors = constructors;

		// Add the vtable type to the struct.
		auto vtableStruct = createVtableStruct(_class.location, _struct, methods);
		_class.vtableStruct = vtableStruct;

		// Add the vtable instance to the struct.
		auto vtableVar = new ir.Variable();
		vtableVar.location = _class.location;
		vtableVar.name = "__vtable";
		vtableVar.type = new ir.PointerType(new ir.TypeReference(vtableStruct, vtableStruct.name));
		_struct.myScope.addValue(vtableVar, vtableVar.name);
		_struct.members.nodes ~= vtableVar;

		// Add the vtable global var to the struct.
		auto vtableGlobalVar = new ir.Variable();
		vtableGlobalVar.location = _class.location;
		vtableGlobalVar.name = "__vtableGlobal";
		vtableGlobalVar.storage = ir.Variable.Storage.Global;
		vtableGlobalVar.type = copyTypeSmart(_class.location, vtableStruct);
		_struct.myScope.addValue(vtableGlobalVar, vtableGlobalVar.name);
		_struct.members.nodes ~= vtableGlobalVar;

		if (methods.length > 0) {
			auto vtableLiteral = new ir.StructLiteral();
			vtableLiteral.location = _class.location;
			vtableLiteral.type = copyTypeSmart(_class.location, vtableStruct);

			foreach (f; methods) {
				vtableLiteral.exps ~= buildExpReference(_class.location, f, f.name);
			}

			vtableGlobalVar.assign = vtableLiteral;
		}

		// Add the fields.
		foreach (field; fields) {
			auto var = copyVariableSmart(_struct.location, field);
			_struct.myScope.addValue(var, var.name);
			_struct.members.nodes ~= var;
		}

		// Add the methods.
		foreach (method; myMethods) {
			_struct.myScope.addFunction(method, method.name);
			_struct.members.nodes ~= method;
		}

		if (_struct.name == "TypeInfo" && _struct.myScope.parent.name == "object" && _struct.myScope.parent.parent is null) {
			// object.TypeInfo shouldn't have a constructor -- it is built with struct literals.
			return _struct;
		}

		// And finally, create and add the constructor.
		auto ctor = createConstructor(_struct, vtableStruct, constructors, vtableGlobalVar);
		_struct.myScope.addFunction(ctor, ctor.name);
		_struct.members.nodes ~= ctor;
		_class.constructor = ctor;
		foreach (userConstructor; constructors) {
			userConstructor.name = "__user_ctor";
			_struct.myScope.addFunction(userConstructor, userConstructor.name);
			_struct.members.nodes ~= userConstructor;
		}

		return _struct;
	}

	override void transform(ir.Module m)
	{
		allocDgVar = retrieveAllocDg(m.location, m.myScope);
		foreach (ident; m.name.identifiers) {
			parentNames ~= ident.value;
		}
		internalScope = m.myScope;
		internalTLB = m.children;
		passNumber = 0;
		accept(m, this);
		passNumber = 1;
		accept(m, this);
	}

	override void close()
	{
	}

	/**
	 * For every member of the given TopLevelBlock,
	 * check if it is a class. If it is, lower it
	 * in place using synthesiseClassStruct.
	 */
	override Status enter(ir.TopLevelBlock tlb)
	{
		if (passNumber != 0) return Continue;
		foreach (i, node; tlb.nodes) {
			if (node.nodeType == ir.NodeType.Class) {
				auto asClass = cast(ir.Class) node;
				assert(asClass !is null);
				auto n = createClassStruct(asClass);
				assert(n !is null);
				tlb.nodes[i] = n;
				n.myScope.parent.remove(n.name);
				n.myScope.parent.addType(n, n.name);
				assert(tlb.nodes[i].nodeType == ir.NodeType.Struct);
			}
		}
		return Continue;
	}

	/// Turn type into a pointer to a lowered class struct if it's currently a Class. 
	void replaceTypeIfNeeded(ref ir.Type type)
	{
		auto asTR = cast(ir.TypeReference) type;
		if (asTR is null) {
			return;
		}
		auto asClass = cast(ir.Class) asTR.type;
		if (asClass is null) {
			auto asStruct = cast(ir.Struct) asTR.type;
			if (asStruct !is null && asStruct.loweredNode !is null && asStruct.loweredNode.nodeType == ir.NodeType.Class) {
				type = new ir.PointerType(asTR);
				type.location = asTR.location;
			}
			return;
		}
		auto n = createClassStruct(asClass);
		n.myScope.parent.remove(n.name);
		n.myScope.parent.addType(n, n.name);
		asTR.type = cast(ir.Type) n;
		assert(asTR.type !is null);
		asTR.names[0] = asTR.type.mangledName;
		type = new ir.PointerType(asTR);
		type.location = asTR.location;
	}

	override Status enter(ir.ArrayType arrayType)
	{
		replaceTypeIfNeeded(arrayType.base);
		return Continue;
	}

	override Status enter(ir.FunctionType ftype)
	{
		replaceTypeIfNeeded(ftype.ret);
		foreach (ref param; ftype.params) {
			accept(param, this);
		}
		return Continue;
	}

	override Status enter(ir.DelegateType dtype)
	{
		replaceTypeIfNeeded(dtype.ret);
		foreach (ref param; dtype.params) {
			accept(param, this);
		}
		return Continue;
	}

	override Status enter(ir.Unary unary)
	{
		if (unary.op == ir.Unary.Op.Cast && unary.type.nodeType == ir.NodeType.TypeReference) {
			replaceTypeIfNeeded(unary.type);
		}
		return Continue;
	}

	/**
	 * When we encounter a Variable, if it is a
	 * a instance of a class, turn it into a pointer
	 * to the lowered class struct.
	 */
	override Status enter(ir.Variable var)
	{
		super.enter(var);
		replaceTypeIfNeeded(var.type);
		return Continue;
	}

	/// Given a new expression, create a call to the correct class's constructor.
	ir.Exp createConstructorFromNewExp(ir.Unary newExp)
	in
	{
		assert(newExp.op == ir.Unary.Op.New);
	}
	body
	{
		auto asTR = cast(ir.TypeReference) newExp.type;
		assert(asTR !is null);
		/// @todo Remove when we can new more stuff.
		auto asClass = cast(ir.Class) asTR.type;

		assert(asClass !is null);
		assert(asClass.constructor !is null);

		// Object.__ctor
		auto ctorCall = new ir.ExpReference();
		ctorCall.location = newExp.location;
		ctorCall.idents ~= asClass.name;
		ctorCall.idents ~= asClass.constructor.name;
		ctorCall.decl = asClass.constructor;

		auto pfix = new ir.Postfix();
		pfix.location = newExp.location;
		pfix.op = ir.Postfix.Op.Call;
		pfix.child = ctorCall;
		pfix.arguments ~= newExp.argumentList;

		return pfix;
	}

	override Status enter(ref ir.Exp exp, ir.Unary unary)
	{
		if (passNumber != 1) return Continue;
		if (unary.op != ir.Unary.Op.New) {
			return Continue;
		}

		auto asTR = cast(ir.TypeReference) unary.type;
		if (asTR is null) {
			return Continue;
		}

		auto asClass = cast(ir.Class) asTR.type;
		if (asClass is null) {
			return Continue;
		}

		/*
		 * Check that the number of arguments passed to
		 * new is the same as the class's constructor.
		 */
		if (asClass.userConstructors.length > 0 && asClass.userConstructors[0].type.params.length != unary.argumentList.length) {
			throw new CompilerError(unary.location, "no match for constructor (bad number of arguments).");
		} else if (asClass.userConstructors.length == 0 && unary.argumentList.length > 0) {
			throw new CompilerError(unary.location, "no user constructor yet arguments supplied.");
		}

		exp = createConstructorFromNewExp(unary);

		return Continue;
	}

	/**
	 * When we encounter a postfix call calling a class
	 * instance, replace the call with a look up into
	 * the vtable.
	 */
	override Status enter(ir.Postfix postfix)
	{
		if (passNumber != 1) return Continue;
		if (postfix.op != ir.Postfix.Op.Call) {
			return Continue;
		}

		auto postfixChild = cast(ir.Postfix) postfix.child;
		if (postfixChild is null || postfixChild.op != ir.Postfix.Op.Identifier) {
			return Continue;
		}

		if (postfixChild.child.nodeType != ir.NodeType.ExpReference) {
			return Continue;
		}

		auto asRef = cast(ir.ExpReference) postfixChild.child;
		assert(asRef !is null);

		auto asVar = cast(ir.Variable) asRef.decl;
		if (asVar is null) {
			return Continue;
		}

		auto asPointer = cast(ir.PointerType) asVar.type;
		if (asPointer is null) {
			return Continue;
		}

		auto asTR = cast(ir.TypeReference) asPointer.base;
		if (asTR is null) {
			return Continue;
		}
		
		ir.Class asClass;
		auto asStruct = cast(ir.Struct) asTR.type;
		if (asStruct !is null && asStruct.loweredNode !is null && asStruct.loweredNode.nodeType == ir.NodeType.Class) {
			asClass = cast(ir.Class) asStruct.loweredNode;
		}
		if (asClass is null) {
			return Continue;
		}

		auto store = asStruct.myScope.lookupOnlyThisScope(postfixChild.identifier.value, postfix.location);
		if (store is null || store.functions.length == 0) {
			return Continue;
		}
		assert(store.functions.length >= 1);
		assert(asClass.vtableStruct !is null);
		if (store.functions[$-1].vtableIndex == -1) {
			throw CompilerPanic(postfix.location, "bad vtable index on class method.");
		}

		auto vtable = new ir.Postfix();
		vtable.location = postfix.location;
		vtable.op = ir.Postfix.Op.Identifier;
		vtable.identifier = new ir.Identifier();
		vtable.identifier.location = postfix.location;
		vtable.identifier.value = "__vtable";
		vtable.child = asRef;

		auto methodLookup = new ir.Postfix();
		methodLookup.location = postfix.location;
		methodLookup.op = ir.Postfix.Op.Identifier;
		methodLookup.identifier = new ir.Identifier();
		methodLookup.identifier.location = postfix.location;
		methodLookup.identifier.value = "_" ~ to!string(store.functions[0].vtableIndex);
		methodLookup.child = vtable;

		auto newRef = buildExpReference(asRef.location, asVar, asRef.idents);
		auto _cast = new ir.Unary(new ir.PointerType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Void)), newRef);
		_cast.location = postfix.location;

		postfix.child = methodLookup;
		postfix.arguments ~= _cast;

		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		currentFunctionScope = fn.myScope;
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		currentFunctionScope = null;
		return Continue;
	}

	/**
	 * The exptyper inserts empty thises in classes as the this variable
	 * doesn't exist at that point. It should now, so just go and fill
	 * those in.
	 */
	override Status visit(ir.ExpReference expref)
	{
		if (expref.idents[0] != "this" || expref.decl !is null || currentFunctionScope is null ||
			passNumber == 0) {
			return Continue;
		}

		auto thisStore = currentFunctionScope.lookupOnlyThisScope("this", expref.location);
		if (thisStore is null) {
			return Continue;
		}

		auto asVar = cast(ir.Variable) thisStore.node;
		if (asVar is null) {
			throw new CompilerError(expref.location, "non variable this.");
		}

		expref.decl = asVar;

		return Continue;
	}
}
