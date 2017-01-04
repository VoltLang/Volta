module test;

fn letUsRecurseDeeply(a: i32, b: void*, c: void*, d: void*)
{
	e := new ItThatHoldsThatAssociativeArrayForTesting();
	f := [1, 2, 3] ~ [4, 5, 6];
	if (a >= 100) {
		return;
	}
	letUsRecurseDeeply(a + 1, null, null, null);
}

class ItThatHoldsThatAssociativeArrayForTesting
{
	theAAThatItIsHolding: string[string];
}

fn main() i32
{
	it := new ItThatHoldsThatAssociativeArrayForTesting();
	it.theAAThatItIsHolding["hello"] = "world";
	letUsRecurseDeeply(0, null, null, null);
	p := "hello" in it.theAAThatItIsHolding;
	return *p == "world" ? 0 : 1;
}

