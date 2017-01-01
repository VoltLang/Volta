module test;

fn accumulate2(x: i32) i32
{
	if (x >= 20) {
		return x;
	}
	return accumulate1(x + 1);
}

fn accumulate1(x: i32) i32
{
	if (x >= 20) {
		return x;
	}
	return accumulate2(x + 1);
}

fn twenty() i32
{
	return accumulate1(0) - 20;
}

fn main() i32
{
	return #run twenty();
}

