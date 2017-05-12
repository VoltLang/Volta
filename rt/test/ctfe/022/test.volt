module test;

alias A = u32;
enum u32 E0 = 0u;
enum u32 E1 = typeid(A).size * 8u;
enum u32 E2 = E0 / E1 == 0u ? 2u : E0 / E1;

fn main() i32
{
	return cast(i32)(E2 - 2);
}

