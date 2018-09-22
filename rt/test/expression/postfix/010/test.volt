module test;

import core.object : Object;

fn main() i32
{
	obj := Object.default;
	return obj is null ? 0 : 27;
}
