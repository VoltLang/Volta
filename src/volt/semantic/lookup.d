module volt.semantic.lookup;

import ir = volt.ir.ir;

ir.Store lookup(ir.Scope _scope, string name)
{
	auto current = _scope;
	while (current !is null) {
		auto store = current.getStore(name);
		if (store !is null) {
			return store;
		}
		current = current.parent;
	}
	return null;
}

