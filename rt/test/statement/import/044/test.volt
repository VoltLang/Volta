//T macro:importfail
module test;

static import foo.bar.baz;
import foo = m1;

fn main() i32
{
	return foo.exportedVar;
}
