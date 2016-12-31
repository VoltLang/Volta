// Test appending to an array (append-assign).
module test;


fn main() i32
{
	i: i32[] = [0, 1];
	i ~= 2;

	d: f64[] = [0.0, 1.0];
	d ~= 2;

	s: string[] = ["Volt", "is", "truly"];
	s ~= "amazing";

	if(i[0] == 0 && i[1] == 1 && i[2] == 2 && i.length == 3 &&
	   d[0] == 0 && d[1] == 1 && d[2] == 2 && d.length == 3 &&
	   s[3] == "amazing" && s.length == 4)
		return 0;
	else
		return 42;
}
