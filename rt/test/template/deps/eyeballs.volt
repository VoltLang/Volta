module eyeballs;

private enum V = 5;

union Eyeballs!(T)
{
	global a: T = V;
}
