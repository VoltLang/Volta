module vls.semantic.actualiseClass;
/* This should be replaced once the semantic pass
 * proper is made no throw and we can use the real
 * resolution stuff.
 */

import watt.io;
import ir = volta.ir;

import vls.util.simpleCache;
import vls.semantic.lookup;

fn actualise(ref cache: SimpleImportCache, _class: ir.Class)
{
	if (_class.isActualized) {
		return;
	}
	_class.isActualized = true;
	fillInParents(ref cache, _class);
}

private:

fn fillInParents(ref cache: SimpleImportCache, _class: ir.Class)
{
	if (_class.parent is null) {
		return;
	}
	store := lookup(ref cache, _class.myScope, _class.parent);
	if (store is null) {
		return;
	}
	_class.parentClass = store.node.toClassChecked();
	if (_class.parentClass !is null) {
		actualise(ref cache, _class.parentClass);
	}
}
