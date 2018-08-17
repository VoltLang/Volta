module volt.bbe;

import ir = volta.ir;
import io = watt.io;

fn process(modules: ir.Module[]) i32 {
	foreach (i, mod; modules) {
		io.writeln(new "${i} ${mod.name}");
	}
	return 12;
}
