//T macro:expect-failure
//T check:'x' is neither field
/* This would generate a circular dependency error as the
 * UFCS code would look for a function `x` using the regular
 * lookup functions, but it would find the initial variable,
 * which hadn't finished resolving.
 */
module test;

fn main() i32 {
	return 0;
}

fn connectRoom(targetEdge: i32) {

	x := targetEdge.x;
}
