Comparing Volt and C
---

At a glance, Volt and C are similar languages. They both (usually) compile down to executables or libraries, are imperative languages and use curly braces to denote scopes.

What's The Same
---

As mentioned in the intro, Volt is conceptually similar to C, but beyond that, let's get into some details.

Volt has inherited a lot of **statements** from C, so most of these will look familiar.

	if (thisIsTrue()) {
		// then this happens
	}

	while (thisIsTrue()) {
		// this keeps happening
	}

	do {
		// this keeps happening, and once at minimum
	} while (thisIsTrue());

	for (i = 0; i < 10; ++i) {
		// this happens 10 times
	}

	switch (i) {
	case 0: doZero(); break;
	case 1: doOne(); break;
	default: doN(i); break;
	}

	return 0;  // Return a value from a function.

	assert(condition(), "message if fails!");  // In Volt, assert is a builtin statement.

Likewise, a lot of the **expressions** are the same.

	a = 12;  // Assign a value to a variable.

	a = &b;  // Take the address of another variable.

	a = *b;  // Dereference another variable.

	a = b + c * d - (e / f) - (g % h);  // Binary operators have the same precedence as in C.

	a++; ++a; a--; a--;  // Pre and postfix increment and decrement.

	a = b[5];  // Index into an array.

	a = b.field;  // Read a field of a user-defined type.

	a(1, 2, 3);  // Call a function.

And combine all the above with the fact that Volt is compatible with C libraries, and ships with bindings to the C standard library by default, it shouldn't take experienced C programmers long to get up and running with the basics of Volt.

	import core.stdc.stdio;

	fn main() i32
	{
		printf("hello world\n");
		return 0;
	}

What's Different
---

Of course, if Volt were just C with a coat of paint, you could emulate it with a header file full of horrific macros, so what's different about Volt? What might catch the aforementioned experienced C programmers by surprise?

Perhaps the most subtle but important distinction is the **module** system. If you have a function that adds two numbers together in C, you might have this in `add.c`:

	int add(int a, int b)
	{
		return a + b;
	}

Then, you create a header file in `add.h`:

	#ifndef _ADD_H_
	#define _ADD_H_

	int add(int a, int b);

	#endif  /* _ADD_H_ */

And then `#include` it in `main.c`:

	#include "add.h"

	int main()
	{
		return add(40, 2);
	}

The `#include` directive tells the C preprocessor to insert the contents of `add.h` at the top of `main.c`, and then when its compiled, the linker puts it all together. The important thing to note here is that `#include` is textual: it has no semantic information about what's going on (hence things like the header guards, to stop multiple inclusions).

What if were to to the above, in Volt? Well, in `add.volt`, we might do something very similar:

	module add;

	fn add(a: i32, b: i32) i32
	{
		return a + b;
	}

And then in `main.volt`:

	module main;

	import add;

	fn main() i32
	{
		return add(40, 2);
	}

So each `.volt` file is a module. The name of the module is written up the top, right after `module`. You'll notice there's no `add.h` equivalent in the Volt example. That's because the `import` statement does something very different to `#include`: instead of saying "include this module at this point", what it says is "if an unknown identifier is used, before erroring, look in this module for a definition".

Because `import` is not textual, but semantic, nothing like the 'header guard' is needed:

	import add;
	import add;
	import add;
	import add;
	import add;  // Silly, but inconsequential.

What if your code is a proprietary library, meaning you don't want to give the source code out to everybody? In C, you'd just ship the `.h` file, but what do you do in Volt?

Well, nothing is stopping you from making a Volt 'header' file:

	module add_header;

	fn add(a: i32, b: i32) i32;

There's more complicated things that can be done with import statements, but other documentation is a better source for that information. For the moment, just be aware that `import` is similar, but different, to `#include` directives.

Syntax
---

Perhaps the most obvious difference, but once you understand it, it's not a massive departure.

In C, you declare a variable like so:

	T var;

In Volt, the syntax is a little different:

	var: T;

Multiple declarations use commas, like C:

	var1, var2: T*;

Note that the types of `var1` and `var2` in the above example is a pointer to `T`. Unlike in the C example:

	T* var1, var2;

Where `var1` is a pointer, but `var2` is not.

Primitive Types
---

The types of Volt are of specific sizes. For example, instead of an `int` (which in C is only guaranteed to be 16 bits or more in size, but can be larger), in Volt you'd use `i32`, which is a 32 bit signed integer. The unsigned integer, instead of using a keyword like C, is just another type: `u16` is an unsigned 16 bit integers.

**Integers**

	i8, i16, i32, i64, u8, u16, u32, u64

**Floating Point Values**

	f32, f64  // equivalent to float and double in most modern C environments.

**Characters**

	char, wchar, dchar  // utf-8, utf-16, utf-32, respectively

**Other**

	bool, void
