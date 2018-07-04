module contrived;

private enum V = 12;

class Contrived!(T)
{
	fn foo() T
	{
		return V;
	}
}
