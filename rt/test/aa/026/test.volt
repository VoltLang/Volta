module test;

fn main() i32
{
	arr: immutable(u32)[] = [1, cast(u32)-1];
	arr2: immutable(u32)[] = [1, 0];

	map: i32[immutable(u32)[]];
	map[arr] = 5;

	if ((arr in map) is null) {
		return 1;
	}
	if ((arr2 in map) !is null) {
		return 2;
	}

	return map[arr] - 5;
}
