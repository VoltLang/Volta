module test;

fn main() i32
{
    a := "hello";
    b := ["world"];
    assert(new "${a}" == `hello`);
    assert(new "${b}" == `["world"]`);
    return 0;
}
