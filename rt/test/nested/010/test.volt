//T default:no
//T macro:expect-failure
//T check:cannot overload nested
module test;

fn main() i32
{
    fn add(a: i32, b: i32) i32
    {
        return 12;
    }

    fn add(c: i64, d: i64) i32
    {
        return 24;
    }

    return add(12, 5);
}
