module test;

fn main() i32
{
	c := 'a';
	assert(new "${c}" == `a`, new "${c}");
	assert("${'a'}" == `a`, "${'a'}");
	return 0;
}
