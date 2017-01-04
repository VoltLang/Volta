//T default:no
//T macro:expect-failure
//T check:cannot implicitly convert
// Shouldn't be able to treat i as a pointer.
module test;


fn  addOne(ref i: i32)
{
	ip: i32* = i;
}

fn main() i32
{
	i: i32 = 29;
	addOne(i);
	return i;
}
