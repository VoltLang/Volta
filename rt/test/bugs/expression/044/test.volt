//T default:no
//T macro:expect-failure
module test;

fn main() i32
{
	if (["a", "b", "c"] == 3) {
		return 1;
	}
	return 0;
}
