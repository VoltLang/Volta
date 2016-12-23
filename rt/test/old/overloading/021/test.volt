//T compiles:yes
//T retval:42
module test;

// We use a array here to force the type to be different enough
// from the first arg to select the other function, its important
// we should match the other func.
void bug(int[]) {}
void bug(int, string[] foo...) { val += 20; }

void otherBug() {}
void otherBug(int, string[] foo...) { val += 22; }

global int val;

int main()
{
	// Its probably easier to fix them in this order.
	// The above order is in the order I found them.
	otherBug(1);

	bug(1);

	return val;
}
