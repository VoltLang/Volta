module volt.semantic.typeidreplacer;

import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.expreplace;
import volt.semantic.classify;
import volt.semantic.lookup;
import volt.semantic.mangle;

ir.Scope getScope(ir.Type type)
{
	auto pointer = cast(ir.PointerType) type;
	if (pointer !is null) return getScope(pointer.base);

	auto tr = cast(ir.TypeReference) type;
	if (tr !is null) return getScope(tr.type);

	auto _struct = cast(ir.Struct) type;
	if (_struct !is null) return _struct.myScope;

	auto _class = cast(ir.Class) type;
	if (_class !is null) return _class.myScope;

	return null;
}

/**
 * Replaces typeid(...) expressions with a call
 * to the TypeInfo's constructor.
 */
class TypeidReplacer : NullExpReplaceVisitor, Pass
{
public:
	Settings settings;
	ir.Struct typeinfo;
	ir.Struct typeinfoVtable;
	ir.Module thisModule;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

	override void transform(ir.Module m)
	{
		thisModule = m;
		
		typeinfo = retrieveTypeInfoStruct(m.location, m.myScope);
		auto store = typeinfo.myScope.lookupOnlyThisScope("__Vtable", m.location);
		if (store is null || store.node is null || store.node.nodeType != ir.NodeType.Struct) {
			throw CompilerPanic(m.location, "couldn't retrieve TypeInfo vtable struct.");
		}
		typeinfoVtable = cast(ir.Struct) store.node;

		assert(typeinfo !is null);
		assert(typeinfoVtable !is null);
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ref ir.Exp exp, ir.Typeid _typeid)
	{
		assert(_typeid.type !is null);

		int typeSize = size(_typeid.location, _typeid.type);
		auto typeConstant = new ir.Constant();
		typeConstant.location = _typeid.location;
		typeConstant.value = to!string(typeSize);
		typeConstant.type = settings.getSizeT();

		int typeTag = _typeid.type.nodeType;
		auto typeTagConstant = new ir.Constant();
		typeTagConstant.location = _typeid.location;
		typeTagConstant.value = to!string(typeTag);
		typeTagConstant.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
		typeTagConstant.type.location = _typeid.location;

		auto mangledNameConstant = new ir.Constant();
		mangledNameConstant.location = _typeid.location;
		auto _scope = getScope(_typeid.type);
		string[] parentNames;
		if (_scope !is null) {
			parentNames = getParentScopeNames(_scope);
		}
		mangledNameConstant.value = mangle(parentNames, _typeid.type);
		mangledNameConstant.arrayData = cast(void[]) mangledNameConstant.value;
		mangledNameConstant.type = new ir.ArrayType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Char));

		bool mindirection = mutableIndirection(_typeid.type);
		auto mindirectionConstant = new ir.Constant();
		mindirectionConstant.location = _typeid.location;
		mindirectionConstant.value = mindirection ? "true" : "false";
		mindirectionConstant.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		mindirectionConstant.type.location = _typeid.location;

		auto vtable = new ir.StructLiteral();
		vtable.location = _typeid.location;
		vtable.type = new ir.TypeReference(typeinfoVtable, typeinfoVtable.name);

		auto vtableVar = new ir.Variable();
		vtableVar.location = thisModule.location;
		vtableVar.assign = vtable;
		vtableVar.mangledName = vtableVar.name = _typeid.type.mangledName ~ "__TypeInfo_vtable";
		vtableVar.type = new ir.TypeReference(typeinfoVtable, typeinfoVtable.name);
		vtableVar.isWeakLink = true;
		vtableVar.storage = ir.Variable.Storage.Global;
		thisModule.children.nodes = vtableVar ~ thisModule.children.nodes;

		auto vtableRef = new ir.ExpReference();
		vtableRef.location = vtableVar.location;
		vtableRef.idents ~= vtableVar.name;
		vtableRef.decl = vtableVar;
		auto vtableAddr = new ir.Unary();
		vtableAddr.location = vtableRef.location;
		vtableAddr.op = ir.Unary.Op.AddrOf;
		vtableAddr.value = vtableRef;

		auto literal = new ir.StructLiteral();
		literal.location = _typeid.location;
		literal.type = new ir.TypeReference(typeinfo, typeinfo.name);

		literal.exps ~= vtableAddr;
		literal.exps ~= typeConstant;
		literal.exps ~= typeTagConstant;
		literal.exps ~= mangledNameConstant;
		literal.exps ~= mindirectionConstant;

		auto literalVar = new ir.Variable();
		literalVar.location = vtableVar.location;
		literalVar.assign = literal;
		literalVar.mangledName = literalVar.name = _typeid.type.mangledName ~ "__TypeInfo";
		literalVar.type = new ir.TypeReference(typeinfo, typeinfo.name);
		literalVar.isWeakLink = true;
		literalVar.storage = ir.Variable.Storage.Global;
		thisModule.children.nodes = literalVar ~ thisModule.children.nodes;

		auto literalRef = new ir.ExpReference();
		literalRef.location = literalVar.location;
		literalRef.idents ~= literalVar.name;
		literalRef.decl = literalVar;
		auto literalAddr = new ir.Unary();
		literalAddr.location = literalRef.location;
		literalAddr.op = ir.Unary.Op.AddrOf;
		literalAddr.value = literalRef;

		exp = literalAddr;

		return Continue;
	}
}
