// Large numbers and AAs.
module test;

fn main() i32
{
	aa: u64[u64];
	aa[u64.max] = u64.max;
	aa = new aa[..];
	return aa[u64.max] > u32.max ? 0 : 42;
}
