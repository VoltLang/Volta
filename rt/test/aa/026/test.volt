module test;

fn main() i32
{
	arr: immutable(u32)[] = [0u];
	arr2: immutable(u32)[] = [1u];
	map: i32[immutable(u32)[]];
	map[arr] = 5;
	assert((arr in map) !is null);
	return map[arr] - 5;
}
