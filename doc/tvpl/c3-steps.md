# Chapter 3 - First Steps

## Values

We'll go into more detail later, but for now it's enough to know that numbers can be given to `writeln` too.

	import watt.io;
  
	fn main() i32
	{
		writeln(42);
		return 0;
	}

Should output `42` onto your console.

## Variables

Variables hold values. Numbers like the `42`, above, or 'strings' of text, like `hello, world` from the last chapter. In the simplest cases, defining a variable is easy. Just give a name, and the value you want to associate with it.

	import watt.io;

	fn main() i32
	{
		numberOfMonths := 12;
		firstMonth := "January";
		qwriteln(numberOfMonths);
		writeln(firstMonth);
	}

Will output:

	12
	January

This is useful enough, but as their name implies, we can change the contents of a variable.

	n := 1;
	writeln(n);
	n = 2;
	writeln(n);

Output:

	1
	2

Note that the first time we *define* the variable, we use type inference operator `:=`. This asks the compiler to create a new variable of the name before the `:=`, and assign it a given value. `=` is the 'assignment operator'. This asks the compiler to assign a value to an already defined variable. Variables can't be given the same name. It's slightly more complicated than that, in reality, but that will come later.

The above is a shorthand. Volt is what is a 'statically typed' language; variables and expressions always have a 'type'. `3` is an integer, and `"hello"` is a `string`. Once a variable has been declared as a type, it cannot be changed.

	n := 1;
	n = "hello";   // ERROR: can't convert string to an integer.
	n := "hello";  // ERROR: variable 'n' is already defined.

What if we want to declare a variable, but we don't have a value to assign it right away? How do we give it a type without using `:=`? Well, A long form version of the example from the beginning of the section is as follows:

	import watt.io;
	
	fn main() i32
	{
		numberOfMonths: i32 = 12;
		firstMonth: string = "January";
		writeln(numberOfMonths);
		writeln(firstMonth);
	}

Semantically, the program is identical. Typographically, it's a little longer. This means you can define a variable, and then assign to it later:

	n: i32;
	// ...
	n = 2;

We'll talk more about types later on. For now, it is enough to know that they exist, and that for most of our examples we will be using integers, represented in Volt as `i32`.

# Maths!
