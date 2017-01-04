module test;

fn twenty() i32
{
	return 0;
}

enum Twenty = #run twenty();

fn main() i32
{
	return Twenty;
}

