//T compiles:no
module test;

i32 make(string name,(i32 vb)
{
	return vb;
}

fn main() i32
{
	return make("apple", 12);
}
