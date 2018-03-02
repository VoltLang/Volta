module main;

fn main() i32
{
	str := new "\\${12}";
	if (str != `\12`) {
		return 1;
	} else {
		return 0;
	}
}
