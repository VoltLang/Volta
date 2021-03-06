---
layout: page
---

## The Volt Programming Language ##

Volt is a systems programming language that aims to be expressive but not at the expense of clarity and control.

## Lexical ##

Volt source files have the extension `.volt`, and are processed as UTF-8.

*Comments* are ignored by the compiler, and come in three varieties.

    // This is a single line comment, terminate by a newline.
    /* This is a c-style block comment, cannot nest. */
    /+ /+ These block comments can nest. +/ This is still a comment. +/

*Doc Comments* can attach documentation to declarations to be output to HTML or JSON via the --doc or --json commands.

    /** A doccomment */
    /// And another.

By default, doccomments will attach to the next single declaration.

    /// ichi is marked with this comment.
    fn ichi();
    // but ni receives no comment.
    fn ni();
	/// This is an error, as there is no declaration to attach to.

Line doccomments can be made to the previous declaration.

    fn san();  ///< This attaches to san.

Usually, one doccomment goes to one declaration. However, you can apply doccomments to multiple declarations.

    /// This comment attaches to alpha and beta.
	/// @{
	fn alpha();
	struct beta {}
	/// @}

Omitting the closing comment brace is an error.

*Keywords* are reserved, and cannot be used as identifiers.

    abstract alias align asm assert auto
    body bool break byte
    case cast catch
    cdouble cent cfloat char class const continue creal
    dchar debug default delegate delete deprecated do double
    else enum export extern
    f32 f64 false final finally float for foreach foreach_reverse function
    global goto
    i8 i16 i32 i64 isize idouble if ifloat immutable import in inout int interface
    invariant ireal is
    lazy local long
    macro mixin module
    new nothrow null
    out override
    package pragma private protected public
    real ref return
    scope shared short static struct super switch synchronized
    template this throw true try typedef typeid typeof
    u8 u16 u32 u64 usize ubyte ucent uint ulong union unittest ushort
    va_arg version void volatile wchar while with
    __thread __traits __FILE__ __FUNCTION__ __LINE__ __PRETTY_FUNCTION__

Furthermore, the following are handled specially by the lexer.

    __DATE__     // Replaced with the date at compilation.
    __EOF__      // Treated as the EOF by the lexer.
    __TIME__     // Replaced with the time at compilation.
    __VENDOR__   // Replaced with a compiler specific string.
    __VERSION__  // Replaced with an integer representing the compiler version.

*Identifiers* start with a letter or underscore, and contain letters, underscores, or numbers.

    foo, _id, a_name32

*Integer Literals* start with a number from `1` to `9`, `0x`, or `0b` and can contain _, and can end with U, L, or UL.

    100    // i32, 100
    10_0   // i32, 100
    32U    // u32, 32
    64L    // i64, 64
    128UL  // u64, 128
    0b0010 // i32, 2
    0xFF   // i32, 255
    0123   // Error, as some languages would treat this as an octal. 

*Floating Point Literals* start with a digit, contain a `.` and can end in `f`.

    1.23   // f64, 1.23
    1.23f  // f32, 1.23

There are a few *String Literals*.

    "Hello, world."    // A UTF-8 string.
    "Hello,\nworld."   // Contains a newline character.
    r"Hello,\nworld."  // Contains 'Hello,\nworld.' literally.
    `Hello,\nworld.`   // As above, but can also use '"' character in the string.

## Modules ##

Modules correspond directly with source files, and start with a module declaration, giving their name.

    module a_module_name;

    struct MyStruct;

The declarations in the above module can then be accessed from another module with an *import statement*.

    import a_module_name;  // Symbols directly accessible.

    global MyStruct myStruct;

Imports can be marked as `static` which requires the module name to be prefixed to lookups.

    static import a_module_name;

    global a_module_name.MyStruct myStruct;

Module names can be given `package` names by separating the names with `.`.

    module foo.bar.baz;

The above would usually correspond with a file in a path like `foo/bar/baz.volt`, but this is merely convention.

Multiple imports can be given in one statement.

    import a, b, c;

And specific symbols can be imported from modules (without importing the rest of the symbols.

    import math : cos, sin, tan;

`public` imports will have the effect of `import`ing modules into any module that imports the module with the public imports.

    module a;

    global integer: i32;

<!-- -->

    module b;

    public import a;

<!-- -->

    module c;

    import a;

    // Can access 'integer'.

If a directory contains a file named `package.volt`, an `import` of that directory will be rewritten to `directoryname.package`. You can use this along with `public` imports to implement a package in multiple source files, but accessible with just one `import`.

The `module` declaration is recommended for every module, but for quick programs it can just be extra unneeded typing. The declaration can be omitted, but a module that uses this 'anonymous module' method, cannot be imported by another module.

## Simple Types ##

*Primitive Types* are the simplest form of abstraction available. Most of these have legacy keywords (indicated in the comments). These currently function for compatibility purposes, but should not be relied on remaining.

    bool    // Is either 'true' or 'false'.
    i8      // Signed 8 bit value. (legacy keyword: 'byte')
    u8      // Unsigned 8 bit value. (legacy keyword: 'ubyte')
    i16     // Signed 16 bit value. (legacy keyword: 'short')
    u16     // Unsigned 16 bit value. (legacy keyword: 'ushort')
    i32     // Signed 32 bit value. (legacy keyword: 'int')
    u32     // Unsigned 32 bit value. (legacy keyword: 'uint')
    i64     // Signed 64 bit value. (legacy keyword: 'long')
    u64     // Unsigned 64 bit value. (legacy keyword: 'ulong')
    f32     // 32 bit floating point value. (legacy keyword: 'float')
    f64     // 64 bit floating point value. (legacy keyword: 'double')

Various suffixes can be attached to these types to make new types.

    i32[]    // A dynamic (resizable at run-time) array of ints.
    i32[32]  // A static (size fixed at compile-time) array of 32 ints.
    i32*     // A pointer to an int. Can be 'null'.
    i32[i32] // An associative array of ints, indexed by an int key.

And various prefixes change how the types behave.

    const(i32)   // An integer that cannot be modified.
    const(i32)[] // An array of integers that cannot be modified, but the array itself can.
    const(i32[]) // An array of integers that cannot be modified, and neither can the array itself.

Note that there is no way to write `i32 const([])`. That is to say, an array that cannot be modified with contents that can be modified. `const` (and other qualifiers) are *transitive*; they apply to themselves and their children.

`immutable` is similar to `const`, except `immutable` values guarantee (save the programmer deliberately going around the type system with `cast`) that there are no mutable references to the data at all.

To put it another way, mutable and `immutable` values can become `const`, but only `immutable` values (this includes types that cannot be modified by another reference, like plain integers for example) can become `immutable`.

## Functions ##

Functions are declared using the `fn` keyword:

    fn areEqual(a: i32, b: i32) bool
        return a == b;
    }

The above declares a function `areEqual`, that takes two `i32`s and returns a `bool`. The following function returns nothing, and takes no arguments:

     fn doNothing() {
         return;
     }

Calling them works as you'd expect.

    areEqual(1, 2);
    doNothing();


Usually, parameters are pass-by-value.

    fn makeThree(var: i32) {
         var = 3;
    }

    ...
        x := 2;
        makeThree(x);
        // x remains 2.

However, if you mark a parameter as `ref`, the value will be updated.

    fn makeThree(ref var: i32) {
         var = 3;
    }

    ...
        x := 2;
        makeThree(ref x);  // The 'ref' here is required, too.
        // x is 3.

`out` works in a similar fashion except variables passed to the function are default initialised, even if nothing is written to them.

The simplest form of variadics (functions that can take multiple arguments) are *homogeneous variadics*. These are simply functions that have a parameter that can be several (or none) of the same type.

    fn sum(numbers: i32[]...) {
        result: i32;
        foreach (number; numbers) {
            result += number;
        }
        return result;
    }

The variadic parameter (marked with `...`) must be the final parameter, and must be an array type.

The above function can be called in several ways.

    sum(1, 2, 3)    // returns 6
    sum([1, 2, 3])  // returns 6
    sum()           // returns 0

The first two calls are equivalent. As you can see, the function always handles an array, no matter how it's called.

If you need more power, Volt also has true runtime *variadic function*s. The syntax is similar, except the `...` gets its own parameter.

    import core.exception;
    import watt.varargs;

    fn sum(...) i32 {
        vl: va_list;

        va_start(vl);
        result: i32;
        foreach (tid; _typeids) {
            if (tid.type != object.TYPE_INT) {
                throw new Exception("sum: expected i32");
            }
            result += va_arg!i32(vl);
        }
        va_end(vl);
        return result;
    }

## Structs ##

*Structs* are the simplest aggregate type. In their simplest form, they bundle several declarations together.

    struct S {
        x: i32;
        string s;
        s: string
    }

    ...
        s: S;
        s.x = 42;
        s.s = "hello"

The above struct is allocated on the stack, but we can ask the GC to allocate a struct too.

    sp: S* = new S;
    sp.x = 32;  // No special access syntax required.

Structs can contain functions. A reference to the struct is implicit in each function, and accessible implicitly or through the `this` keyword.

    struct S {
        x: i32;
        fn xSquaredTimesN(n: i32) i32 {
            return (x * this.x) * n;
        }
    }

    ...
        s: S;
        s.x = 2;
        s.xSquaredTimesN(3);  // 12.

## Unions ##

Unions are like structs, except all the variables occupy the same piece of memory.

    union U {
        x: i32;  // Setting x...
        y: i32;  // ...will set y, too.
    }


## Classes ##

*Classes* are superficially similar to structs at first glance, but are quite different. The core concept to keep in mind is structs represent **data** and are fairly low level (what a C++ programmer might call POD -- *P*lain *O*ld *D*ata) and classes represent high level concepts.

Classes in volt are single inheritance and always reference types, so if you've used Java or C# you won't be too confused.

As mentioned, at first glance they look like structs.

    class C {
        x: i32;
    }

But there are several differences already. Firstly when using them.

    c: C;       // Default initialised to null.
    // c.x      // Crashes!
    c = new C;
    c.x = 2;

Furthermore, classes can have constructors.

    class C {
        x: i32;
        this() {
            x = 3;
        }
        this(x: i32) {
            this.x = x;
        }
        this(x: i32, y: i32) {
            this.x = x * y;
        }
    }

    ...
        a := new C();     // x == 3
        b := new C(4);    // x == 4
        c := new C(2, 3); // x == 6

 Classes can also have functions, which we call *methods*.

    class C {
        fn getInt() i32 {
            return 42;
        }
    }

They've a different name because of *inheritance* they behave differently. A class can be a child of a class (but only one!) like so.

    class D : C {
         fn getAnotherInt() i32 {
             return 24;
         }
    }

And D acts like you'd expect.

    d := new D();
    d.getInt();        // 42
    d.getAnotherInt(); // 24

But you can also use a D as a C.

    c: C = d;
    c.getInt();         // 42
    //c.getAnotherInt();  // Error!
    asD := cast(D)c;
    asD.getAnotherInt();  // 24

In addition to this, methods can be overridden, changing their behaviour.

    class D : C {
        override fn getInt() i32 {
            return 7;
        }
    }

    ...
        d := new D();
        c: C = d;
        c.getInt();  // 7, not 42.

If a function is related to a class or struct as a type, but not a particular instance, you can create a *static function*, that needs to be called through the *type*, not the *instance*.

    class Fruit {
        local fn isDelicious() bool {
            return true;
        }
    }

    ...
        fruit := new Fruit();
        // fruit.isDelicious();  // Error!
        Fruit.isDelicious();     // true

Finally, you can mark a function with `@property` if it takes one argument, or no arguments with a non-`void` return value.

    class Person {
        _name: string;
        @property fn name() string {
            return _name;
        }
        @property fn name(n: string) {
            _name = n;
        }
    }

    ...
        p := new Person();
        p.name = "Selma";  // Calls second function as name("Selma").
        s: string = p.name; // Calls first function as name();


## Interfaces ##

Class can implement multiple *interface*s, which are a set of methods with no implementation.

    interface IPerson {
        fn age() i32;
        fn name() string;
    }

Then a class can give the list of interfaces it implements after its parent class (if one is specified).

    class C : /*ParentClass, */IPerson {
        override fn age() i32 { return 11; }
        override fn name() string { return "Billy"; }
    }

If one of the specified methods is not implemented, an error is generated. As for *why* one would want to do this, variables with a type of interface can be declared, and implementing classes can be treated as an instance of that interface.

    fn ageTimesTwo(person: IPerson) i32 {
        return person.age() * 2;
    }

    ...
        c := new C();
        ageTimesTwo(c);  // Note: no cast needed.

This allows classes of entirely different family trees to be adapted to work with the same interface.

## Function Pointers ##

Function pointers can be defined simply.

    fptr : fn (i32, string) bool;  // fptr is variable to a bool returning function that takes an i32 and a string.

Linkages (how the compiler is to call the function pointer) can be set by giving the name after a ! following the `fn` keyword.

    fptra : fn!C () i32;  // A C function pointer.
    fptrb : fn!Volt () i32;  // A Volt function pointer.

The accepted linkages are `Volt` (the default), `C`, `C++`, `D`, `Windows`, `Pascal`, and `System`.

## Unified Function Call Syntax

Unified Function Call Syntax, UFCS for short, is a way of extending types without modifying the type itself.
Without it, if we have a class or struct that lacks a method, we would have to settle for regular function call syntax.

    class Book {
        title: string;
        price: i32;
    }

    fn reducePrice(book: Book, amount: i32) {
        book.price -= amount;
    }

    ...
        reducePrice(book, 4);

But with UFCS, we can call the function as if it were a method.

    ...
        book.reducePrice(4);  // Same as above.

If the struct or class had already defined `reducePrice`, the real method would take precedence over any free functions.

It's not limited to structs and classes either. If a method style lookup would fail on any type (primitive types like i32, etc), then Volt will look for a function that takes the type as the first parameter, then the rest of the arguments.

    fn add(i: i32, a: i32, b: i32) i32 {
        return i + a + b;
    }

    ...
        i32 i = 2;
        i.add(3, 5);  // == 10

## Expressions

### New Expression

Volt is a garbage collected language, which means that the programmer doesn't have to concern themselves with deallocating memory (unless they choose to!).

To request memory from the garbage collector (GC), use the `new` expression. In its simplest form, `new` simply takes a type. In this case, the returned value is a pointer to that type.

    ...
        ip := new i32;  // ip has the type `i32*`.

You can use this with your own `alias`es and `struct`s, but `class`es are a different story. As discussed earlier, classes are reference types, so `new Object()` doesn't give you a pointer to `Object`, but just a plain `Object`. The parens (`()`) are required, and arguments to constructors can be passed.

    class Pair {
        a, b: i32;
        this(a: i32) {
            this.a = a;
        }
        this(a: i32, b: i32) {
            this.a = a;
            this.b = b;
        }
    }

    ...
        // a := new Pair()    // Error! No matching constructor.
        b := new Pair(32);    // Calls the first constructor.
        c := new Pair(10, 5); // Calls the second constructor.

That's not the only place arguments are passed to `new`. Consider `new i32[]`. What's the type that this results in? If you guessed `i32[]*`, you'd be right. If we want to allocate an array with `new`, give it the array type, but append parens with the requested length after it.

    a := new i32[](0);     // An empty array of i32s.
    b := new string[](3);  // An array of three strings.

Speaking of arrays, sometimes you want to make a copy of one. You might think that

    newArray := oldArray;

would suffice, but consider that arrays are defined as structs, internally:

    struct ArrayStruct {
        ptr: void*;
        length: size_t;
    }

With this in mind, it's easy to see why a simple assignment doesn't create a copy -- the pointer is the same! Well, `new` can help here, too:

    newArray := new oldArray[0 .. $];

If that `$` confuses you, it's simply a shorthand for `oldArray.length`. The number before the `..` is the index of `oldArray` to start copying (inclusive0, and the number after is the index to stop (exclusive). It's easy to see how you could copy a portion of an array, if you don't want the whole thing:

    oldArray := [1, 2, 3, 4, 5, 6];
    newArray := new oldArray[3 .. 5];
    // newArray == [4, 5]

And as copying the entire array is a common operation, there's a shorthand for the `0 .. $` syntax too:

    newArray := new oldArray[..];

The above syntax can be used to copy associate arrays, too.

### String Import Expression

    str: string = import("filename.txt");

Will look in the paths supplied to the compiler with the `-J` switch for 'filename.txt'. If it finds it, the import expression will be replaced with a string literal with the contents of that file. If you're using `battery`, it will supply a `res` directory to Volta as the argument for `-J`.

There are no default lookup paths provided, all string imports will fail if `-J` is not used at least once.

## Statements

In addition to statements that will be familiar to any C programmer, `if`, `while`, `for`, and so on, Volt includes a `foreach` statement for quickly looping over arrays and the like. The syntax is familiar to the loops in D, but there are several differences.

    array := [4, 5, 6];
    foreach (e; array) {
        writefln("%s", e);  // Prints "1", then "2", then "3".
    }

In general, the foreach statement can be described as follows.

    foreach ((<index>, )<element>; <aggregate>) { ... }

That is to say, if there are two identifiers before the ';' the first is the index (the current count of iterations of this loop), and the second is the element (the value of this iteration). If there is only one, it just contains the element. These declare variables in the foreach block, but there is a large difference to regular variables: you cannot declare their type.

If the aggregate is not an associative array, the index is always of type `size_t` and the element is the type of one element of the aggregate (e.g. if the aggregate is `i32[]`, then the element is of type `i32`).

If the aggregate *is* an associative array, then the index is the key, and the element is the value.

    aa := ["hello":2];
    foreach (v; aa) {
        writefln("%s", v);  // Prints the value, "2".
    }
    foreach (k, v; aa) {
        writefln("%s %s", k, v);  // Prints "hello 2".
    }

You can also use `foreach` to iterate over an integer range.

    foreach (i; 0 .. 10) {
        writefln("%s", i);   // Prints "0", then "1", and so on, until "9".
    }

If you don't need the element in this case, it can be omitted.

    foreach (0 .. 10) {
        // Runs 10 times.
    }

Using the `foreach_reverse` keyword instead of `foreach` makes the foreach do all of the above, but backwards.
