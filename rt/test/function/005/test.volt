module test;

fn div(numerator: i32, denominator: i32) i32
{
	return numerator / denominator;
}

fn main() i32
{
	return div(denominator:2, numerator:4) * div(numerator:3, denominator:1) - 6;
}
