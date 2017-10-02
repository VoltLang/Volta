//T macro:expect-failure
//T check:no matching
module test;

class A {
	bool func() {
		return true;
	}
}

class B : A {
	override void func() {
	}
}

int main() {
	auto b = new B();
	b.func();
	return 0;
}
