---
layout: page
---

Comparing Volt and C++
---
This page is for people that want to get up to speed on the differences between Volt and C++. We won't be retreading ground covered in [the C comparison](volt-vs-c.html), and most of that is applicable to C++ too, so make sure you read that as well.

What's The Same
---

Object-Oriented Programming
---

Volt has support for things like classes, inheritence, and overloading.

	class Parent
	{		
		fn getX() i32
		{
			return x;
		}
	}
	
	class Child : Parent
	{
		override fn getX() i32
		{
			return 1;
		}
	}

	...
	p: Parent = new Child();
	return p.getX();  // Returns 1.

Functions
---

Volt does function overloading:

	fn foo()
	{
	}
	
	fn foo(i: i32)
	{
	}

	...
	foo();
	foo(1);

As mentioned in the [C document](volt-vs-c.html), Volt supports pass by reference.

	fn addOne(ref i: i32)
	{
		i++;
	}
	
	i: i32 = 0;
	addOne(ref i);
	return i;  // 1.

Statements
---

You can **throw** things in much the same way.

	import core.exception;
	
	fn main() i32
	{
		try {
			throw new Exception("message");
		} catch (Exception e) {
			// Do something with e.
		} finally {
		}
		return 0;
	}

What's Different
---

Expressions
---

Like C++11, Volt has type inferred variables. Instead of

	auto a = 0;  // type of a is an int

Volt does:

	a := 0;  // type of a is an i32

At the moment, Volt just has one **cast**, like C:

	b := cast(u8)a;

There are plans to add a `recast` that would be conceptually similar to C++'s `reinterpret_cast`, however.

Namespaces
---

Volt does not have namespaces *per se*. The module system (as documented in the [C comparison document](volt-vs-c.html)) is the replacement. When `import`ing a module, you can make it a `static` import, forcing an access through the module name explicitly:

	static import core.stdc.stdio;
	
	...
	printf("hello\n");  // Error: unknown identifier 'printf'.
	core.stdc.stdio.printf("hello\n");  // Okay.

You can shorten these names by creating an alias when importing:

	static import libc = core.stdc.stdio;
	...
	libc.printf("hello\n");

Memory Management
---

The default setup for Volt is with Garbage Collection. The collector can be changed, or disabled, and functions will be able to be asserted to not use the GC with `@nogc`.

This does mean that class destructors will not run when the instance goes out of scope, as in C++, but when a collection is next made (which may not be until program exit). So if you need clean up to happen, there are various methods, but the easiest is perhaps with a **scope** block:

	inst := new MyCoolObject();
	scope (exit) inst.cleanup();  // When the current scope is left, this code will be called.

The block is like any other statement block, and can use braces to encapsulate multiple child statements:

	scope (exit) {
		func1();
		func2();
	}

The `exit` in the parameters means that if the scope is left via normal methods (i.e. a `return`) or exceptional ones (i.e. a `throw`), that scope block will be run. There are two other modes `success` and `failure`; `success` means that only a return will trigger that block, and `failure` means that a throw will trigger it, but a return will not.

Object-Oriented Programming
---

Volt classes do not have multiple inheritance. Java-style inheritance is supported to bridge that gap.

Objects are always references to an instance of the class, allocated on the heap.

	obj: Object;  // obj is null.
	obj = new Object();  // allocated via the GC on the heap.
