//T macro:expect-failure
//T check:functions may not be named 'init'
module test;

fn init(x: i32)
{
}

fn main() i32
{
    init(12);
    return 0;
}
