//T default:no
//T macro:do-not-link
module test;

fn foo()
{
	version (none) {
		uniform!("[]", char, char)('0', '9');
	}
}

