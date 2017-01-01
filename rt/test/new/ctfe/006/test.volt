module test;

fn thirty() i32
{
	return 30;
}

fn sixty() i32
{
	return (thirty() * 2) - 60;
}

fn main() i32
{
	return #run sixty();
}
