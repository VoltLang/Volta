//T default:no
//T macro:expect-failure
module test;

fn div(numerator: i32, denominator: i32) i32
{
	return numerator / denominator;
}

fn main() i32
{
	return div(denominator:2, 4);
}
