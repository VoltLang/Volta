module volt.semantic.classlowerer;

import std.array : insertInPlace;
import std.conv : to;
import std.stdio;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.expreplace;
import volt.visitor.visitor;
import volt.semantic.classify;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.token.location;

ir.Postfix createFunctionCall(Location location, ir.Scope _scope, string name, ir.Exp[] arguments...)
{
	auto iexp = new ir.ExpReference();
	iexp.location = location;
	iexp.idents ~= name;

	auto store = _scope.lookup(name);
	if (store is null || store.functions.length == 0) {
		throw CompilerPanic(location, format("couldn't find function of name of '%s'", name));
	}
	assert(store.functions.length == 1);

	iexp.decl = store.functions[0];

	auto pfix = new ir.Postfix();
	pfix.location = location;
	pfix.op = ir.Postfix.Op.Call;
	pfix.child = iexp;
	pfix.arguments = arguments.dup;

	return pfix;
}

class ClassLowerer : NullExpReplaceVisitor, Pass
{
public:
	ir.Scope internalScope;
	ir.TopLevelBlock internalTLB;
	ir.Struct[ir.Class] synthesised;
	string[] parentNames;
	int passNumber;

public:
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
	ir.Function createConstructor(ir.Struct c, ir.Struct vtable, ir.Function[] userConstructors)
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
		fn.type.ret = objVar.type;

		if (userConstructors.length > 0) {
			assert(userConstructors.length == 1);

			foreach (param; userConstructors[0].type.params[0 .. $-1]) {
				fn.type.params ~= new ir.Variable();
				fn.type.params[$-1].location = c.location;
				fn.type.params[$-1].name = param.name;
				fn.type.params[$-1].type = param.type;
			}
		}

		fn.type.hiddenParameter = true;

		fn.myScope = new ir.Scope(c.myScope, c, null);

		// Object.sizeof
		int sz = size(c.location, c);
		auto objSizeof = new ir.Constant();
		objSizeof.location = c.location;
		objSizeof.value = to!string(sz);
		objSizeof.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Uint);  // @todo use Settings.

		// cast(Object*) malloc(Object.sizeof);
		ir.Postfix mallocCall = createFunctionCall(c.location, c.myScope, "malloc", objSizeof);
		auto castExp = new ir.Unary(objVar.type, mallocCall);
		castExp.location = c.location;

		objVar.assign = castExp;
		fn._body.statements ~= objVar;

		// obj expression
		auto objRef = new ir.ExpReference();
		objRef.location = c.location;
		objRef.decl = objVar;
		objRef.idents ~= "obj";

		// Object.__Vtable.sizeof;
		sz = size(vtable.location, vtable);
		auto vtableSizeof = new ir.Constant();
		vtableSizeof.location = vtable.location;
		vtableSizeof.value = to!string(sz);
		vtableSizeof.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Uint);  // aieee

		// cast(Object.__Vtable*) malloc(Object.__Vtable.sizeof);
		ir.Postfix vtableMallocCall = createFunctionCall(c.location, c.myScope, "malloc", vtableSizeof);

		auto vtableMallocCast = new ir.Unary(new ir.PointerType(new ir.TypeReference(vtable, vtable.name)), vtableMallocCall);
		vtableMallocCast.location = vtable.location;

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
		vtableAssign.right = vtableMallocCast;

		auto expStatement = new ir.ExpStatement();
		expStatement.location = c.location;
		expStatement.exp = vtableAssign;
		fn._body.statements ~= expStatement;

		ir.Function[] functions = getStructFunctions(c);
		foreach (i, methodfn; functions) {
			methodfn.vtableIndex = cast(int)i;

			auto vindex = new ir.Postfix();
			vindex.location = c.location;
			vindex.op = ir.Postfix.Op.Identifier;
			vindex.child = vtableAccess;
			vindex.identifier = new ir.Identifier();
			vindex.identifier.location = c.location;
			vindex.identifier.value = "_" ~ to!string(i);

			auto methodfnexpref = new ir.ExpReference();
			methodfnexpref.location = c.location;
			methodfnexpref.idents ~= methodfn.name;
			methodfnexpref.decl = methodfn;

			auto methodAssign = new ir.BinOp();
			methodAssign.location = c.location;
			methodAssign.op = ir.BinOp.Type.Assign;
			methodAssign.left = vindex;
			methodAssign.right = methodfnexpref;

			auto methodiexp = new ir.ExpStatement();
			methodiexp.location = c.location;
			methodiexp.exp = methodAssign;
			fn._body.statements ~= methodiexp;
		}

		// obj.__user_ctor(arg1, arg2, obj);
		if (userConstructors.length > 0) {
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
		auto retstatement = new ir.ReturnStatement();
		retstatement.location = c.location;
		retstatement.exp = objRef;
		fn._body.statements ~= retstatement;

		return fn;
	}

public:
	/**
	 * Create a vtable struct for a given class.
	 *
	 * A vtable struct is a struct with function pointers
	 * of the class methods on it.
	 */
	ir.Struct createVtableStruct(Location location, ir.Function[] functions)
	{
		import std.stdio;

		auto _struct = new ir.Struct();
		_struct.location = location;
		_struct.myScope = new ir.Scope(internalScope, _struct, null);
		_struct.name = "__Vtable";
		_struct.defined = true;

		_struct.members = new ir.TopLevelBlock();
		_struct.members.location = _struct.location;

		foreach (i, _function; functions) {
			auto var = new ir.Variable();
			var.location = _struct.location;
			var.name = format("_%s", i);
			var.type = _function.type;
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
	 * Side-effects: the hidden this parameter is added to functions
	 *               that do not have it.
	 */
	ir.Function[] getMethods(ir.Class[] inheritanceChain, ir.Struct _struct)
	{
		import std.stdio;

		// Each parameter needs a unique this or the LLVM IR generated is bad.
		ir.Variable getThis()
		{
			auto thisVar = new ir.Variable();
			thisVar.location = inheritanceChain[0].location;
			thisVar.name = "argThis";
			thisVar.type = new ir.PointerType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Void));
			return thisVar;
		}

		ir.Function[] methods;
		int[string] definedMethods;
		for (int i = cast(int)(inheritanceChain.length - 1); i >= 0; --i) {
			auto _class = inheritanceChain[i];
			foreach (node; _class.members.nodes) {
				if (node.nodeType != ir.NodeType.Function) {
					continue;
				}
				auto asFunction = cast(ir.Function) node;

				assert(asFunction !is null);
				if (!asFunction.type.hiddenParameter) {
					asFunction.type.params ~= getThis();

					auto argThis = new ir.ExpReference();
					argThis.location = inheritanceChain[0].location;
					argThis.idents ~= "argThis";
					argThis.decl = asFunction.type.params[$-1];

					auto _cast = new ir.Unary(new ir.PointerType(new ir.TypeReference(_struct, _struct.name)), argThis);
					_cast.location = inheritanceChain[0].location;

					auto thisVar = new ir.Variable();
					thisVar.location = inheritanceChain[0].location;
					thisVar.name = "this";
					thisVar.type = new ir.PointerType(new ir.TypeReference(_struct, _struct.name));
					thisVar.type.location = inheritanceChain[0].location;
					thisVar.assign = _cast;
					if (asFunction._body !is null) {
						asFunction._body.statements = thisVar ~ asFunction._body.statements;
					}
					asFunction.myScope.addValue(thisVar, "this");

					asFunction.type.hiddenParameter = true;
				}
				// Don't add constructors to the method list.
				if (asFunction.kind == ir.Function.Kind.Constructor) {
					continue;
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
		_struct.name = name;
		_struct.location = _class.location;
		_struct.myScope = new ir.Scope(internalScope, _struct, null);
		_struct.members = new ir.TopLevelBlock();
		_struct.members.location = _class.location;
		_struct.mangledName = name;
		_struct.loweredNode = _class;
		synthesised[_class] = _struct;

		// Retrieve the methods and fields for this class.
		auto inheritanceChain = getInheritanceChain(_class);
		auto methods = getMethods(inheritanceChain, _struct);
		auto fields = getFields(inheritanceChain);
		auto constructors = getConstructors(inheritanceChain);

		/// @todo When we have function overloading, allow multiple constructors.
		if (constructors.length > 1) {
			throw CompilerPanic(_class.location, "multiple constructors not supported.");
		}
		_class.userConstructors = constructors;

		// Add the vtable type to the struct.
		auto vtableStruct = createVtableStruct(_class.location, methods);
		_struct.myScope.addType(vtableStruct, vtableStruct.name);
		_struct.members.nodes ~= vtableStruct;
		_class.vtableStruct = vtableStruct;

		// Add the vtable instance to the struct.
		auto vtableVar = new ir.Variable();
		vtableVar.location = _class.location;
		vtableVar.name = "__vtable";
		vtableVar.type = new ir.PointerType(new ir.TypeReference(vtableStruct, vtableStruct.name));
		_struct.myScope.addValue(vtableVar, vtableVar.name);
		_struct.members.nodes ~= vtableVar;

		// Add the fields.
		foreach (field; fields) {
			_struct.myScope.addValue(field, field.name);
			_struct.members.nodes ~= field;
		}

		// Add the methods.
		foreach (method; methods) {
			_struct.myScope.addFunction(method, method.name);
			_struct.members.nodes ~= method;
		}

		// And finally, create and add the constructor.
		auto ctor = createConstructor(_struct, vtableStruct, constructors);
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
				internalScope.addType(n, n.name);
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
		auto n = cast(ir.Type) createClassStruct(asClass);
		assert(n !is null);
		asTR.type = n;
		asTR.names[0] = asTR.type.mangledName;
		type = new ir.PointerType(asTR);
		type.location = asTR.location;
	}

	override Status enter(ir.FunctionType ftype)
	{
		replaceTypeIfNeeded(ftype.ret);
		foreach (ref param; ftype.params) {
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

		/* Check that the number of arguments passed to new is the same as the class's
		 * constructor minus one. Minus one because the user constructor has a hidden
		 * this parameter.
		 */
		if (asClass.userConstructors.length > 0 && asClass.userConstructors[0].type.params.length - 1 != unary.argumentList.length) {
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

		auto store = asStruct.myScope.getStore(postfixChild.identifier.value);
		if (store is null || store.functions.length == 0) {
			return Continue;
		}
		assert(store.functions.length == 1);
		assert(asClass.vtableStruct !is null);
		if (store.functions[0].vtableIndex == -1) {
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

		auto _cast = new ir.Unary(new ir.PointerType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Void)), asRef);
		_cast.location = postfix.location;

		postfix.child = methodLookup;
		postfix.arguments ~= _cast;

		return Continue;
	}
}
