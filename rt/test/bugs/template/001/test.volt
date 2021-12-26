//T has-passed:no
module test;

fn tmpl!(T)(t: T) T { return t; }

fn main() i32
{
	tmplInstance(0);
	return 0;
}

// This must come after main, to force it to be unresolved as main looks it up.
fn tmplInstance = tmpl!(i32);
