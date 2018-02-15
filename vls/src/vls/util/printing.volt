module vls.util.printing;

import watt = watt.text.sink;
import ir = volta.ir;
import irprinter = volta.ir.printer;

fn functionString(func: ir.Function) string
{
	ss: watt.StringSink;
	ss.sink(new "fn ${func.name}(");
	foreach (i, param; func.params) {
		if (func.type.isArgRef[i]) {
			ss.sink("ref ");
		} else if (func.type.isArgOut[i]) {
			ss.sink("out ");
		}
		ss.sink(new "${param.name}: ${irprinter.printType(param.type)}");
		if (i < func.params.length - 1) {
			ss.sink(", ");
		}
	}
	ss.sink(")");
	ss.sink(new " ${irprinter.printType(func.type.ret)}");
	return ss.toString();
}

fn storeString(store: ir.Store) string
{
	ss: watt.StringSink;
	switch (store.kind) with (ir.Store.Kind) {
	case Value:
		var := store.node.toVariableFast();
		ss.sink(var.name);
		ss.sink(`: `);
		ss.sink(irprinter.printType(var.type));
		ss.sink(`;`);
		break;
	case Function:
		func := store.functions[0];  // @todo overloaded functions
		ss.sink(functionString(func));
		ss.sink(`;`);
		break;
	default:
		return null;
	}
	return ss.toString();
}
