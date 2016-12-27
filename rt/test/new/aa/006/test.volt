//T default:no
//T retval:1
//T run:volta -o %t %s
// Invalid key type accessing aa.
module test;

fn main() i32
{
	aa: i32[i32];
	return aa["volt"];
}

