// test zero length string literal
module test;


fn main() i32
{
	ret: i32;

	// Yes this is a length zero array with a valid pointer.
	// This is needed for C integration.
	weird := "";

	if (weird !is null)
		ret += 1;
	if (weird.ptr !is null)
		ret += 1;
	if (weird.length is 0)
		ret += 1;

	return (ret == 3) ? 0 : 1;
}
