//T compiles:yes
//T retval:12
// test various slices.
module test_009;

int main()
{
	int ret;

	// Testing slices.
	auto slice = "volt";

	if (slice is slice)
		ret += 1;
	if (slice[0 .. 1] is slice[0 .. 1])
		ret += 1;
	if (slice[1 .. 2] is slice[1 .. 2])
		ret += 1;

	auto tmp = slice[1 .. 3];
	if (slice[1 .. 3] is tmp)
		ret += 1;
	if (slice[1 .. 2] is tmp[0 .. 1])
		ret += 1;

	// Nothing matches.
	if (slice !is tmp)
		ret += 1;
	if (slice[2 .. 3] !is tmp)
		ret += 1;

	// Length matches but not pointer.
	if (slice[3 .. 4] !is tmp)
		ret += 1;
	if (slice[1 .. 2] !is slice[2 .. 3])
		ret += 1;

	// Pointer match but not length.
	if (slice[1 .. 2] !is tmp)
		ret += 1;
	if (slice[1 .. 4] !is tmp)
		ret += 1;
	if (slice[1 .. 2] !is slice[1 .. 3])
		ret += 1;

	return ret;
}
