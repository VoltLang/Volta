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
	ir.Variable vtableVar;

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

		auto objectStore = m.myScope.lookup("object", m.location);
		if (objectStore is null) {
			throw CompilerPanic(m.location, "couldn't locate object module scope.");
		}

		auto objectScope = objectStore.s;
		if (objectScope is null) {
			throw CompilerPanic(m.location, "Found symbol 'object', but it is not an imported module.");
		}

		auto objectImport = cast(ir.Import) objectStore.node;
		assert(objectImport !is null);
		auto objectModule = objectImport.targetModule;
		assert(objectModule !is null);

		auto vtableVarStore = objectScope.lookupOnlyThisScope("__TypeInfo_vtable", m.location);
		if (vtableVarStore is null) {
			auto vtable = new ir.StructLiteral();
			vtable.location = objectStore.node.location;
			vtable.type = new ir.TypeReference(typeinfoVtable, typeinfoVtable.name);

			vtableVar = new ir.Variable();
			vtableVar.location = objectScope.node.location;
			vtableVar.assign = vtable;
			vtableVar.mangledName = vtableVar.name = "__TypeInfo_vtable";
			vtableVar.type = new ir.TypeReference(typeinfoVtable, typeinfoVtable.name);
			//vtableVar.isWeakLink = true;
			vtableVar.storage = ir.Variable.Storage.Global;

			objectModule.children.nodes = vtableVar ~ objectModule.children.nodes;
			objectScope.addValue(vtableVar, "__TypeInfo_vtable");
		} else {
			vtableVar = cast(ir.Variable) vtableVarStore.node;
		}

		assert(typeinfo !is null);
		assert(typeinfoVtable !is null);
		assert(vtableVar !is null);
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
		auto _scope = getScopeFromType(_typeid.type);
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
