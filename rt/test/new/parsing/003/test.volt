//T default:no
//T macro:do-not-link
module test;

fn foo()
{
	version (none) {
		a.b!i32();
	}
}
