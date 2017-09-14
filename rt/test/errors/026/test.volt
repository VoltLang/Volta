//T macro:expect-failure
//T check:expected 'case'
module test;

fn main() i32
{
    x := 74;
    switch (x) {
    case 0: .. 75:
        return 1;
    default:
        return 2;
    }
}
