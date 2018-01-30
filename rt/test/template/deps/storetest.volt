module storetest;

struct ValueStore!(T, V: T)
{
	fn get() T
	{
		return V;
	}
}

struct ValueDoubler!(T, V: T)
{
	fn get() T
	{
		return cast(T)(V * 2);
	}
}

struct FortyStore = mixin ValueStore!(i32, 40);
struct PiDoubler  = mixin ValueDoubler!(f64, 3.1415926538);
