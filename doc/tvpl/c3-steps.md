# Chapter 3 - First Steps

This chapter will be a whirlwind tour of a lot of features. We'll go more in depth next chapter, but this ensures everybody is on the same page. Let's go!

## Displaying Values

We'll go into more detail later, but for now it's enough to know that numbers can be given to `writeln` too.

	import watt.io;
  
	fn main() i32
	{
		writeln(42);
		return 0;
	}

Should output `42` onto your console. Don't worry about the `return 0` for now.

## Variables

Variables hold values. Numbers like the `42`, above, or 'strings' of text, like `hello, world` from the last chapter. In the simplest cases, defining a variable is easy. Just give a name, and the value you want to associate with it.

	import watt.io;

	fn main() i32
	{
		numberOfMonths := 12;
		firstMonth := "January";
		writeln(numberOfMonths);
		writeln(firstMonth);
		return 0;
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
		return 0;
	}

Semantically, the program is identical. Typographically, it's a little longer. This means you can define a variable, and then assign to it later:

	n: i32;
	// ...
	n = 2;

We'll talk more about types later on. For now, it is enough to know that they exist, and that for most of our examples we will be using integers, represented in Volt as `i32`.

## Maths!

	import watt.io;
	
	fn main() i32
	{
		writeln(1 + 1);
		return 0;
	}

Output:

	2

Numbers on their own aren't that useful. Volt can do addition as above. Subtraction:

	0 - 5  // output: -5

Multiplication:

	5 * 2  // output: 10

Division:

	4 / 2  // output: 2

This one deserves a little elaboration. Integers are whole numbers. We'll touch on 'real' numbers later, but be aware that the above is 'integer division'. Any fractional portion is ignored:

	5 / 2  // output: 2, NOT 2.5

If you know anything about maths you'll know that dividing by zero is not possible. So what happens if we try it?

	8 / 0

This program has no output; the OS will kill the process for performing an illegal operation.

You can also mix expressions with numbers, and variables that hold numbers:

	n := 3
	n - 2  // output: 1

There are many more expressions, which we will enumerate in the next chapter.

## Arrays

Say we wanted to store the names of the months. We could do it with individual variables, as we've been doing:

	firstMonth := "January";
	secondMonth := "February";
	...
	twelthMonth := "December";

This works, but there's a more elegant way. Use an array:

	months := ["January", "February", "March", "April", "May",
		"June", "July", "August", "September", "October", "November", "December"]
	writeln(months[0]);
	writeln(months[11]);
	writeln(months[1+1]);

Output:

	January
	December
	March

An array contains multiple values in a single variable. The above would be called "an array of strings". Arrays must be of the same type. We can look up the value with an 'index expression'. The numbering starts from zero, which is why `months[1]` would be `February` and *not* `January`. You can create an array that contains no values with a new expression:

	months := new string[](12);
	months[0] = "January";
	...

The `12` in the example above is the length of the array; how many values it holds. You can get this value by using the `.length` property of arrays:

	writeln(months.length);  // output:12

## Foreach Statement

So far the programs we've written have all been very linear. They start at the top, and run all our code until they get to the end. What if we took our previous example, and wanted to display all the months. We *could* do something like this:

	import watt.io;
	
	fn main() i32
	{
		months := ["January", "February", "March", "April", "May",
			"June", "July", "August", "September", "October", "November", "December"];
		writeln(months[0]);
		writeln(months[1]);
		...
		writeln(months[11]);
		return 0;
	}

But there's an easier way. Statements *do* things. In this case, the `foreach` runs some code **for** **each** entry in a list.

	import watt.io;
	
	fn main() i32
	{
		months := ["January", "February", "March", "April", "May",
			"June", "July", "August", "September", "October", "November", "December"];
		foreach (month; months) {
			writeln(month);
		}
		return 0;
	}

Output:

	January
	February
	...
	December

This runs `writeln(month)` twelve times; once for every element in the array 'months'. We can also print out what iteration it's on too:

	foreach (i, month; months) {
		writeln(i);
		writeln(month);
	}

Output:

	0 January
	1 February
	...
	11 December

Notice that like our `main` function, the `foreach` statement has `{` and `}`. These group statements together. They also affect how variables are looked up, a topic which we'll get into in a few sections. But first, functions.

## Functions

Functions are a block of code that can be 'called' to do a thing by other pieces of code.

	import watt.io;
	
	fn sayHello()
	{
		writeln("Hello");
	}

	fn main() i32
	{
		sayHello();
		sayHello();
		sayHello();
		return 0;
	}

Output:
	
	Hello
	Hello
	Hello

The keyword `fn NAME` declares a function with a given name. All of our full examples have featured a function: `main`. Main is a special function -- it's the first function called when your program is run.

Functions can optionally have return values. These go after the `()`. Our `main` function returns an integer: `i32`. You can store this value and use it like any other:

	import watt.io;
	
	fn getZero() i32
	{
		return 0;
	}

	fn main() i32
	{
		a := getZero();
		writeln(a);  // 0
		return 0;
	}

We can give values to functions to work with by defining a 'parameter list': a special list of variables that we give to the function when we call it.

	import watt.io;
	
	fn sayHello(name: string)
	{
		writeln("Hello there...");
		writeln(name);
	}
	
	fn main() i32
	{
		sayHello("Bob");
		sayHello("Jenny");
		return 0;
	}

Output:

	Hello there...
	Bob
	Hello there....
	Jenny

## Scope

Scope defines who can see which variables. If we make a variable outside of a function, it is known as a 'global' variable, and we even have to mark it as such:

	import watt.io;
	
	global n: i32 = 2;
	
	fn main() i32
	{
		writeln(n);  // 2
		n := 3;  // ERROR: n is already defined.
		return 0;
	}

A variable defined in a block statement is a 'local' variable, and can only be seen in that scope, and block statements inside of that block statement.

	fn main() i32
	{
		a := 1;
		{
			writeln(a);  // 1
			b := 2;
			writeln(b);  // 2
		}
		writeln(b);  // ERROR: no variable 'b' defined.
		return 0;
	}

## Modules

All Volt code lives in 'modules' -- these correspond to `.volt` files. Our little example code hasn't done it here for the sake of space, but you should always name your modules:

	module a;
	
	global n: i32 = 5;

If we save that in a file `a.volt`, and then have `b.volt`:

	module b;
	
	import a;
	import watt.io;
	
	fn main() i32
	{
		writeln(n);
		return 0;
	}

If you then compile, passing both modules:

	volt a.volt b.volt

The output will be:

	5

You can use functions from modules too. In fact, `import watt.io;` imports a module from the *Watt* standard library that contains the `writeln` function we've been using to output values!

