module volt.semantic.newreplacer;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.exceptions;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.expreplace;
import volt.semantic.classify;
import volt.semantic.lookup;
import volt.semantic.mangle;

ir.Variable retrieveAllocDg(Location location, ir.Scope _scope)
{
	auto objectStore = _scope.lookup("object");
	if (objectStore is null || objectStore.s is null) {
		throw CompilerPanic(location, "couldn't retrieve object module.");
	}
	auto allocDgStore = objectStore.s.lookup("allocDg");
	if (allocDgStore is null || allocDgStore.node is null) {
		throw CompilerPanic(location, "couldn't retrieve allocDg.");
	}
	auto asVar = cast(ir.Variable) allocDgStore.node;
	if (asVar is null) {
		throw CompilerPanic(location, "allocDg is wrong type.");
	}
	return asVar;
}

ir.Struct retrieveArrayStruct(Location location, ir.Scope _scope)
{
	auto objectStore = _scope.lookup("object");
	if (objectStore is null || objectStore.s is null) {
		throw CompilerPanic(location, "couldn't retrieve object module.");
	}
	auto arrayStore = objectStore.s.lookup("ArrayStruct");
	if (arrayStore is null || arrayStore.node is null) {
		throw CompilerPanic(location, "couldn't retrieve object.ArrayStruct.");
	}
	auto asStruct = cast(ir.Struct) arrayStore.node;
	if (asStruct is null) {
		throw CompilerPanic(asStruct.location, "object.ArrayStruct is wrong type.");
	}
	return asStruct;
}

ir.Function createArrayAllocFunction(Location location, Settings settings, ir.Scope baseScope, ir.ArrayType atype)
{
	auto arrayMangledName = mangle(null, atype);

	auto countVar = new ir.Variable();
	countVar.location = location;
	countVar.type = settings.getSizeT();
	countVar.name = "count";
	auto countRef = new ir.ExpReference();
	countRef.location = location;
	countRef.idents ~= "count";
	countRef.decl = countVar;

	auto ftype = new ir.FunctionType();
	ftype.location = location;
	ftype.ret = atype;
	ftype.params ~= countVar;

	auto fn = new ir.Function();
	fn.location = location;
	fn.type = ftype;
	fn.name = "__arrayAlloc" ~ arrayMangledName;
	fn.myScope = new ir.Scope(baseScope, fn, fn.name);
	fn.myScope.addValue(countRef, "count");
	fn._body = new ir.BlockStatement();
	fn._body.location = location;

	auto arrayStruct = retrieveArrayStruct(location, baseScope);
	auto allocDgVar = retrieveAllocDg(location, baseScope);

	auto arrayStructVar = new ir.Variable();
	arrayStructVar.location = location;
	arrayStructVar.name = "from";
	arrayStructVar.type = new ir.TypeReference(arrayStruct, arrayStruct.name);
	fn._body.statements ~= arrayStructVar;
	auto arrayStructRef = new ir.ExpReference();
	arrayStructRef.location = location;
	arrayStructRef.idents ~= "from";
	arrayStructRef.decl = arrayStructVar;

	auto ptrPfix = new ir.Postfix();
	ptrPfix.location = location;
	ptrPfix.op = ir.Postfix.Op.Identifier;
	ptrPfix.child = arrayStructRef;
	ptrPfix.identifier = new ir.Identifier();
	ptrPfix.identifier.location = location;
	ptrPfix.identifier.value = "ptr";

	auto lengthPfix = new ir.Postfix();
	lengthPfix.location = location;
	lengthPfix.op = ir.Postfix.Op.Identifier;
	lengthPfix.child = arrayStructRef;
	lengthPfix.identifier = new ir.Identifier();
	lengthPfix.identifier.location = location;
	lengthPfix.identifier.value = "length";

	auto ptrAssign = new ir.BinOp();
	ptrAssign.location = location;
	ptrAssign.op = ir.BinOp.Type.Assign;
	ptrAssign.left = ptrPfix;
	ptrAssign.right = createAllocDgCall(allocDgVar, settings, location, atype.base, countRef, true);

	auto expStatement = new ir.ExpStatement();
	expStatement.location = location;
	expStatement.exp = ptrAssign;

	fn._body.statements ~= expStatement;

	auto lengthAssign = new ir.BinOp();
	lengthAssign.location = location;
	lengthAssign.op = ir.BinOp.Type.Assign;
	lengthAssign.left = lengthPfix;
	lengthAssign.right = countRef;

	auto addrOf = new ir.Unary();
	addrOf.location = location;
	addrOf.op = ir.Unary.Op.AddrOf;
	addrOf.value = arrayStructRef;

	auto arrayPointer = new ir.PointerType(atype);
	arrayPointer.location = location;

	auto _cast = new ir.Unary(arrayPointer, addrOf);
	_cast.location = location;

	auto deref = new ir.Unary();
	deref.location = location;
	deref.op = ir.Unary.Op.Dereference;
	deref.value = _cast;

	auto returnStatement = new ir.ReturnStatement();
	returnStatement.exp = deref;
	returnStatement.location = location;

	fn._body.statements ~= returnStatement;

	return fn;
}


ir.Exp createAllocDgCall(ir.Variable allocDgVar, Settings settings, Location location, ir.Type type, ir.Exp countArg = null, bool suppressCast = false)
{
	auto adRef = new ir.ExpReference();
	adRef.location = location;
	adRef.idents ~= "allocDg";
	adRef.decl = allocDgVar;

	auto tidExp = new ir.Typeid();
	tidExp.location = location;
	tidExp.type = type;

	auto countConst = new ir.Constant();
	countConst.location = location;
	countConst.value = "0";
	countConst.type = settings.getSizeT();

	auto pfixCall = new ir.Postfix();
	pfixCall.location = location;
	pfixCall.op = ir.Postfix.Op.Call;
	pfixCall.child = adRef;
	pfixCall.arguments ~= tidExp;
	if (countArg is null) {
		pfixCall.arguments ~= countConst;
	} else {
		pfixCall.arguments ~= countArg;
	}

	if (!suppressCast) {
		auto result = new ir.PointerType(type);
		result.location = location;
		auto resultCast = new ir.Unary(result, pfixCall);
		resultCast.location = location;
		return resultCast;
	} else {
		return pfixCall;
	}
}
	
class NewReplacer : NullExpReplaceVisitor, Pass
{
public:
	ir.Variable allocDgVar;
	Settings settings;
	ir.Module thisModule;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}
	
	override void transform(ir.Module m)
	{
		thisModule = m;
		allocDgVar = retrieveAllocDg(m.location, m.myScope);
		accept(m, this);
	}

	override void close()
	{	
	}

	override Status enter(ref ir.Exp exp, ir.Unary unary)
	{
		if (unary.op != ir.Unary.Op.New) {
			return Continue;
		}

		if (unary.index !is null) {
			// WIP, doesn't consider multiple outputs of the same function.
			auto allocFn = createArrayAllocFunction(unary.location, settings, thisModule.myScope, new ir.ArrayType(unary.type));
			thisModule.children.nodes = allocFn ~ thisModule.children.nodes;
			thisModule.myScope.addFunction(allocFn, allocFn.name);

			auto _ref = new ir.ExpReference();
			_ref.location = unary.location;
			_ref.idents ~= allocFn.name;
			_ref.decl = allocFn;

			auto call = new ir.Postfix();
			call.location = unary.location;
			call.op = ir.Postfix.Op.Call;
			call.arguments ~= unary.index;
			call.child = _ref;

			exp = call;

			return Continue;
		}

		exp = createAllocDgCall(allocDgVar, settings, unary.location, unary.type);

		return Continue;
	}
}

