//T default:no
//T macro:import
module test;

import b;

fn foo(Location)
{
}

fn main() i32
{
	l: Location;
	foo(l);
	return 0;
}

