module vls.semantic.actualiseClass;
/* This should be replaced once the semantic pass
 * proper is made no throw and we can use the real
 * resolution stuff.
 */

import watt.io;
import ir = volta.ir;

import vls.semantic.lookup;

fn actualise(_class: ir.Class)
{
	if (_class.isActualized) {
		return;
	}
	_class.isActualized = true;
	fillInParents(_class);
}

private:

fn fillInParents(_class: ir.Class)
{
	if (_class.parent is null) {
		return;
	}
	store := lookup(_class.myScope.parent, _class.parent);
	if (store is null) {
		return;
	}
	node := resolveAlias(store.node, _class.myScope);
	_class.parentClass = node.toClassChecked();
	if (_class.parentClass !is null) {
		actualise(_class.parentClass);
	}
}
