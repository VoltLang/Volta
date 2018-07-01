module get;

private enum V = 10;

public enum pubV = V;

fn getV!(T)() T
{
	return V;
}
