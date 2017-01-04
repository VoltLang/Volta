module test;

fn foo(const(char*)**)
{
        return;
}

fn main() i32
{
        ptr: const(char)**;
        foo(&ptr);
        return 0;
}
