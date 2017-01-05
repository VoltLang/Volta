//T default:no
//T macro:expect-failure
module test;

fn make(string name,(i32 vb) i32
{
	return vb;
}

fn main() i32
{
	return make("apple", 12);
}
