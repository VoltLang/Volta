module volt.bbe;

import vir     = volta.ir;
import bir     = volt.bbe.ir;
import watt    = [watt.io, watt.text.sink];

fn process(modules: vir.Module[]) i32 {
	/*
	foreach (i, mod; modules) {
		if (mod.name.toString() == `src\main.volt`) {
			bbeir.transform(mod);
		}
	}
	return 12;
	*/

	ss: watt.StringSink;

	fn getI32() bir.Type {
		return new bir.Type(bir.Type.Kind.Integer32);
	}

	fn getRef(var: bir.Variable) bir.Value {
		return new bir.Reference(var.name, var);
	}

	functions := new bir.Function[](1);
	a0 := new bir.FunctionParameter("a0", getI32());
	b0 := new bir.FunctionParameter("b0", getI32());
	aevs := new bir.Value[](2);
	add0 := new bir.Instruction(bir.Instruction.Kind.Add, [getRef(a0), getRef(b0)]);
	aevs[0] = new bir.Variable("_0", getI32(), add0);
	zero0 := new bir.IntegerValue(getI32(), 0);
	aevs[1] = new bir.Instruction(bir.Instruction.Kind.Ret, [cast(bir.Value)zero0]);
	block0 := new bir.Block("entry", aevs);
	functions[0] = new bir.Function("add", [a0, b0], getI32(), [block0]);
	functions[0].toStringSink(ss.sink);
	watt.writeln(ss.toString());

	return 0;
}

/*
@fn add(a0: @i32, b0: @i32) @i32 {
entry:
	_0: @i32 = @add a0 b0
	@ret _0;
}

@fn main() @i32 {
entry:
	a0: @i32 = 0;
	a1: @i32 = @call add 40 2
	_0: @i32 = @sub a1 42
	@ret _0;
}
*/