---
title: Volt Syntax Snippets
layout: page
---

# Syntax Snippets

## Top Levels

Declare a module. The name is used by import.

```volt
module packagename.modulename;
````

Import a module. Makes all public symbols in module available.

```volt
import packagename.modulename;
```

Declare a struct. 

```volt
struct StructName {
}
```

Declare a class.

```volt
class ClassName {
}
```

Declare a class, inheriting from a parent class, and implementing an interface.

```volt
class ClassName : ParentClass, AnInterface {
}
```

Declare an interface.

```volt
interface AnInterface {
}
```

Declare an interface that inherits from an interface.

```volt
interface AnInterface : ParentInterface {
}
```

Declare a union.

```volt
union UnionName {
}
```

Declare a named enum.

```volt
enum EnumName {
	EnumChild1,
	EnumChild2,
}
```

Declare a named enum with an explicit base type.

```volt
enum EnumName : string {
	EnumChild1 = "child1",
	EnumChild2 = "child2",
}
```

## Declarations

A variable with a primitive type.

```volt
var: i32;
```

A variable with a pointer to a primitive type.

```volt
var: i32*;
```

A variable with an array of a primitive type.

```volt
var: i32[];
```

A variable with a static array of a primitive type.

```volt
var: i32[100];
```

A variable with an associative array type associating strings with a primitive type.

```volt
var: i32[string];
```

A variable with a function that takes a string and returns a bool type.

```volt
var: fn(string) bool;
```

A variable with a delegate that takes a string and returns a bool type.

```volt
var: dg(string) bool;
```

A variable with a const primitive type, that is being assigned to.

```volt
var: const(i32) = 32;
```

A variable with an inferred type.

```volt
var := 32;
```

An alias to a primitive type.

```volt
alias myInt = i32;
```

A function that takes no arguments and returns void.

```volt
fn aFunction() {
}
```

A function that takes an argument and returns it.

```volt
fn aFunction(arg: i32) i32 {
	return arg;
}
```

A function with an argument that has a default value.

```volt
fn aFunction(arg: string = "hello") {
}
```

A function using homogenous variadics.

```volt
fn aFunction(arg1: i32, strings: string[]...) {
}
```

A function using variadics.

```volt
fn aFunction(arg1: i32, ...) {
}
```

An enum declaration.

```volt
enum A = 32;
```

An enum declaration with an explicit type.

```volt
enum size_t A = 32;
```

## Statements

A return statement.

```volt
return 12;
```

A block statement.

```volt
{
	// More code here.
}
```

An if statement.

```volt
if (condition) {
	// ...
} else if (somethingElse) {
	// ...
} else {
	// ...
}
```

An auto if assignment.

```volt
if (var := couldBeNull()) {
	// var is not null
} else {
	// var was null, not in this scope
}
```

A while loop.

```volt
while (condition) {
	// ...
}
```

A do-while loop.

```volt
do {
	// ...
} while (condition);
```

A for statement.

```volt
for (i: size_t = 0; i < 10; ++i) {
	// ...
}
```

A foreach statement.

```volt
foreach (e; arr) {
	// ...
}
```

A reverse foreach statement. Iterates from the end to the beginning.

```volt
foreach_reverse (e; arr) {
	// ...
}
```

A switch statement.

```volt
switch (var) {
case 1:
	// ...
case 2, 3, 4:
	// ...
case 5 .. 10:
	// ...
default:
	// ...
}
```

A continue statement. Jump to the start of the current loop.

```volt
continue;
```

A break statement. Exit the current loop or case statement.

```volt
break;
```

Goto statements. Only in switch statements. Jump to a case.

```volt
goto case 5;
goto default;
```

With block.

```volt
with (AnEnum) {
	var := EnumValue;
}
```

Try, catch, finally blocks.

```volt
try {
	aFunction();
} catch(e: ExceptionA) {
	// ...
} catch(e: ExceptionB) {
	// ...
} finally {
	// ...
}
```

A throw statement.

```volt
throw new Exception("exception message");
```

Scope statements.

```volt
scope (success) {
	// do a thing when this function exits normally
}
scope (failure) {
	// do a thing when this function exits via a throw statement
}
scope (exit) {
	// do a thing when this function exits normally or via a throw statement
}
```

An assert statement.

```volt
assert(errorIfThisIsFalse, "an optional message");
```

## Binary Expressions

Addition.

```volt
var := 2 + 3;  // 5
```

Subtraction.

```volt
var := 2 - 3;  // -1
```

Multiplication.

```volt
var := 2 * 3;  // 6
```

Division.

```volt
var := 4 / 2;  // 2
```

Modulo.

```volt
var := 5 % 3;  // 2
```

Concatenation.

```volt
var := "hello, " ~ "world";  // "hello, world"
```

Logical or.

```volt
var := a || b;
```

Logical and.

```volt
var := a && b;
```

Binary or.

```volt
var := a | b;
```

Binary and.

```volt
var := a & b;
```

Binary xor.

```volt
var := a ^ b;
```

Equality.

```volt
var := a == b;
```

Non-equality.

```volt
var := a != b;
```

AA lookup.

```volt
pointerToElement := key in aa;
```

Reference equality.

```volt
var := ptra is ptrb;
```

Ternary expression.

```volt
var := condition ? resultIfTrue : resultIfFalse;
```

## Unary Expressions

Address of operator.

```volt
var := &var2;
```

Prefix increment.

```volt
++var;
```

Prefix decrement.

```volt
--var;
```

Negative value.

```volt
var := -var2;
```

Negate.

```volt
var := !var2;
```

Bitwise complement.

```volt
var := ~var2;
```

New expressions.

```volt
var := new i32;  // type is i32*
var2 := new ClassName(constructorArg);  // type is ClassName
var3 := new i32[](5);  // type is i32[]. with a length of 5
```

Duplication expression;

```volt
var: i32[];
// ...
var2 := new var1[..];
```

Type cast.

```volt
obj := cast(Object)var;
```

## Postfix Expressions

Identifier lookup

```volt
var := anAggregate.field;
```

Increment.

```volt
var++;
```

Decrement.

```volt
var--;
```

Function/delegate call.

```volt
aFunction(32);
```

Function/delegate call with explicit named parameters.

```volt
aFunction(paramName:false);
```

Function call with ref parameter.

```volt
aFunction(ref arr);
```

Function call with out parameter.

```volt
aFunction(out arr);
```

Array index.

```volt
var := var2[0];
```

Slice expression.

```volt
var := var2[0 .. 32];
```

Dollar slice expression. Shorthand for the array length.

```volt
var := var2[0 .. $-1];
```

Method call.

```volt
someAggregate.method(32);
```

## Other Expressions

Array literal.

```volt
var := [1, 2, 3];
```

Associative array literal.

```volt
var := ["key1": "value1", "key2": "value2"];
```

String import from file.

```volt
var := import("story.txt");
```

Typeid expression, retrieves TypeInfo.

```volt
var := typeid(var2);
```

## Templates

Template struct

```volt
struct S!(T, val: i32) {
	var: T = val;
}
```

Template instantiation.

```volt
struct SInstance = mixin S!(i32, 32);
```
