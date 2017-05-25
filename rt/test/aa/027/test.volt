module test;

global tests := [
	"a": "isProperty",
];

fn main(args: string[]) i32
{
	assert(tests["a"] == "isProperty");
	return 0;
}
