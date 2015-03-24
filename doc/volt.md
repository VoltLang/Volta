## The Volt Programming Language ##

Volt is a systems programming language that aims to be expressive but not at the expense of clarity and control.

## Lexical ##

Volt source files have the extension `.volt`, and are processed as UTF-8.

*Comments* are ignored by the compiler, and come in three varieties.

    // This is a single line comment, terminate by a newline.
    /* This is a c-style block comment, cannot nest. */
    /+ /+ These block comments can nest. +/ This is still a comment. +/

*Keywords* are reserved, and cannot be used as identifiers.

    abstract alias align asm assert auto
    body bool break byte
    case cast catch
    cdouble cent cfloat char class const continue creal
    dchar debug default delegate delete deprecated do double
    else enum export extern
    false final finally float for foreach foreach_reverse function
    global goto
    idouble if ifloat immutable import in inout int interface
    invariant ireal is
    lazy local long
    macro mixin module
    new nothrow null
    out override
    package pragma private protected public
    real ref return
    scope shared short static struct super switch synchronized
    template this throw true try typedef typeid typeof
    ubyte ucent uint ulong union unittest ushort
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

    100    // int, 100
    10_0   // int, 100
    32U    // uint, 32
    64L    // long, 64
    128UL  // ulong, 128
    0b0010 // int, 2
    0xFF   // int, 255
    0123   // Error, as some languages would treat this as an octal. 

*Floating Point Literals* start with a digit, contain a `.` and can end in `f`.

    1.23   // double, 1.23
    1.23f  // float, 1.23

There are a few *String Literals*.

    "Hello, world."    // A UTF-8 string.
    "Hello"c           // Another UTF-8 string.
    "Hello"w           // UTF-16.
    "Hello"d           // UTF-32.
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

    global int integer;

<!-- -->

    module b;

    public import a;

<!-- -->

    module c;

    import a;

    // Can access 'integer'.

Finally, if a directory contains a file named `package.volt`, an `import` of that directory will be rewritten to `directoryname.package`. You can use this along with `public` imports to implement a package in multiple source files, but accessible with just one `import`.

## Simple Types ##

*Primitive Types* are the simplest form of abstraction available.

    bool     // Is either 'true' or 'false'.
    byte     // Signed 8 bit value.
    ubyte    // Unsigned 8 bit value.
    short    // Signed 16 bit value.
    ushort   // Unsigned 16 bit value.
    int      // Signed 32 bit value.
    uint     // Unsigned 32 bit value.
    long     // Signed 64 bit value.
    ulong    // Unsigned 64 bit value.

Various suffixes can be attached to these types to make new types.

    int[]    // A dynamic (resizable at run-time) array of ints.
    int[32]  // A static (size fixed at compile-time) array of 32 ints.
    int*     // A pointer to an int. Can be 'null'.
    int[int] // An associative array of ints, indexed by an int key.

And various prefixes change how the types behave.

    const(int)   // An integer that cannot be modified.
    const(int)[] // An array of integers that cannot be modified, but the array itself can.
    const(int[]) // An array of integers that cannot be modified, and neither can the array itself.

Note that there is no way to write `int const([])`. That is to say, an array that cannot be modified with contents that can be modified. `const` (and other qualifiers) are *transitive*; they apply to themselves and their children.

`immutable` is similar to `const`, except `immutable` values guarantee (save the programmer deliberately going around the type system with `cast`) that there are no mutable references to the data at all.

To put it another way, mutable and `immutable` values can become `const`, but only `immutable` values (this includes types that cannot be modified by another reference, like plain integers for example) can become `immutable`.

## Functions ##

If you're familiar with other C like languages, functions shouldn't appear too foreign.

    bool areEqual(int a, int b) {
        return a == b;
    }

The above declares a function `areEqual`, that takes two `int`s and returns a `bool`. `void` can be used to mark that a function returns no value. Unlike C, `()` means that a function takes no arguments.

     void doNothing() {
         return;
     }

Calling them works as you'd expect.

    areEqual(1, 2);
    doNothing();


Usually, parameters are pass-by-value.

    void makeThree(int var) {
         var = 3;
    }

    ...
        int x = 2;
        makeThree(x);
        // x remains 2.

However, if you mark a parameter as `ref`, the value will be updated.

    void makeThree(ref int var) {
         var = 3;
    }

    ...
        int x = 2;
        makeThree(ref x);  // The 'ref' here is required, too.
        // x is 3.

`out` works in a similar fashion except variables passed to the function are default initialised, even if nothing is written to them.

The simplest form of variadics (functions that can take multiple arguments) are *homogeneous variadics*. These are simply functions that have a parameter that can be several (or none) of the same type.

    int sum(int[] numbers...) {
        int result;
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

    import watt.varargs;

    int sum(...) {
        va_list vl;

        va_start(vl);
        int result;
        foreach (tid; _typeids) {
            if (tid.type != object.TYPE_INT) {
                throw new Exception("sum: expected int");
            }
            result += va_arg!int(vl);
        }
        va_end(vl);
        return result;
    }

## Structs ##

*Structs* are the simplest aggregate type. In their simplest form, they bundle several declarations together.

    struct S {
        int x;
        string s;
    }

    ...
        S s;
        s.x = 42;
        s.s = "hello"

The above struct is allocated on the stack, but we can ask the GC to allocate a struct too.

    S* sp = new S;
    sp.x = 32;  // No special access syntax required.

Structs can contain functions. A reference to the struct is implicit in each function, and accessible implicitly or through the `this` keyword.

    struct S {
        int x;
        int xSquaredTimesN(int n) {
            return (x * this.x) * n;
        }
    }

    ...
        S s;
        s.x = 2;
        s.xSquaredTimesN(3);  // 12.

## Unions ##

Unions are like structs, except all the variables occupy the same piece of memory.

    union U {
        int x;  // Setting x...
        int y;  // ...will set y, too.
    }


## Classes ##

*Classes* are superficially similar to structs at first glance, but are quite different. The core concept to keep in mind is structs represent **data** and are fairly low level (what a C++ programmer might call POD -- *P*lain *O*ld *D*ata) and classes represent high level concepts.

Classes in volt are single inheritance and always reference types, so if you've used Java or C# you won't be too confused.

As mentioned, at first glance they look like structs.

    class C {
        int x;
    }

But there are several differences already. Firstly when using them.

    C c;       // Default initialised to null.
    // c.x     // Crashes!
    c = new C;
    c.x = 2;

Furthermore, classes can have constructors.

    class C {
        int x;
        this() {
            x = 3;
        }
        this(int x) {
            this.x = x;
        }
        this(int x, int y) {
            this.x = x * y;
        }
    }

    ...
        auto a = new C();       // x == 3
        auto b = new C(4);    // x == 4
        auto c = new C(2, 3); // x == 6

 Classes can also have functions, which we call *methods*.

    class C {
        int getInt() {
            return 42;
        }
    }

They've a different name because of *inheritance* they behave differently. A class can be a child of a class (but only one!) like so.

    class D : C {
         int getAnotherInt() {
             return 24;
         }
    }

And D acts like you'd expect.

    auto d = new D();
    d.getInt();        // 42
    d.getAnotherInt(); // 24

But you can also use a D as a C.

    C c = d;
    c.getInt();         // 42
    //c.getAnotherInt();  // Error!
    auto asD = cast(D) c;
    asD.getAnotherInt();  // 24

In addition to this, methods can be overridden, changing their behaviour.

    class D {
        override int getInt() {
            return 7;
        }
    }

    ...
        auto d = new D();
        C c = d;
        c.getInt();  // 7, not 42.

If a function is related to a class or struct as a type, but not a particular instance, you can create a *static function*, that needs to be called through the *type*, not the *instance*.

    class Fruit {
        static bool isDelicious() {
            return true;
        }
    }

    ...
        auto fruit = new Fruit();
        // fruit.isDelicious();  // Error!
        Fruit.isDelicious();     // true

Finally, you can mark a function with `@property` if it takes one argument, or no arguments with a non-`void` return value.

    class Person {
        string _name;
        @property string name() {
            return _name;
        }
        @property void name(string n) {
            _name = n;
        }
    }

    ...
        auto p = new Person();
        p.name = "Selma";  // Calls second function as name("Selma").
        string s = p.name; // Calls first function as name();


## Interfaces ##

Class can implement multiple *interface*s, which are a set of methods with no implementation.

    interface IPerson {
        int age();
        string name();
    }

Then a class can give the list of interfaces it implements after its parent class (if one is specified).

    class C : object.Object, IPerson {
        int age() { return 11; }
        string name() { return "Billy"; }
    }

If one of the specified methods is not implement, an error is generated. As for *why* one would want to do this, variables with a type of interface can be declared, and implementing classes can be treated as an instance of that interface.

    int ageTimesTwo(IPerson person) {
        return person.age() * 2;
    }

    ...
        auto c = new C();
        ageTimesTwo(c);  // Note: no cast needed.

This allows classes of entirely different family trees to be adapted to work with the same interface.

## Unified Function Call Syntax

Unified Function Call Syntax, UFCS for short, is a way of extending types without modifying the type itself.
Without it, if we have a class or struct that lacks a method, we would have to settle for regular function call syntax.

    class Book {
        string title;
        int price;
    }

    void reducePrice(Book book, int amount) {
        book.price -= amount;
    }

    ...
        reducePrice(book, 4);

But with UFCS, we can call the function as if it were a method.

    ...
        book.reducePrice(4);  // Same as above.

If the struct or class had already defined `reducePrice`, the real method would take precedence over any free functions.

It's not limited to structs and classes either. If a method style lookup would fail on any type (primitive types like int, etc), then Volt will look for a function that takes the type as the first parameter, then the rest of the arguments.

    int add(int i, int a, int b) {
        return i + a + b;
    }

    ...
        int i = 2;
        i.add(3, 5);  // == 10