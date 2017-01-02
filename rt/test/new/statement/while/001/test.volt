//T default:no
//T macro:expect-failure
module test;

fn main() i32
{
	while (true) {
		return 0;
		break;
	}
	return 1;
}
