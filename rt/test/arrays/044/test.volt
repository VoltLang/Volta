module test;

fn main() i32
{
    emptyarr: i32[];
    arr1: i32[][];
    arr1 ~= cast(i32[])null;
    return arr1.length == 1 ? 0 : 1;
}
