module add;

private enum A = 25;

import core.exception;

fn adder!(T)(a: T, b: T) T
{
	if (b == 230) {
		throw new Exception("wow, that was unlucky");
	}
	return a + b + A;
}
