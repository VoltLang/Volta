---
layout: page
---

Failing requiring superhuman programming skill to use Volt, a large percentage of programs that the compiler handles will be invalid, and end with an error. For consistency's sake, these errors should all follow a few rules.

The error message will begin with the location of where the error is generated. Ideally, this should be as specific as possible, and pointing to where the mistake the programmer made (if any) is.

    filename:linenumber:columnnumber

 Next, a tag for the error type. At the moment this is one of three.

 **error**: The program is invalid, and compilation cannot continue until it is changed.

 **warning**: The program is not invalid, compilation will continue, but the program is >probably< in error. Ideally, these should be things that can be suppressed by changing the style the program is written in. For example,

     while (a = 2)

may generate a warning about an assign in a statement, but

     while ((a = 2))

would allow the infinite loop silently. There should also be flags and pragmas for disabling specific warnings.

**panic**: The program may be valid, or it may be invalid, but the compiler has responded incorrectly internally, and must exit. This always indicates a bug in the compiler, regardless of input. These errors may omit locations.

Those tags will be separated from the location by a colon and a space, and will end with the same.

    filename:linunumber:columnnumber: [warning|error|panic]: <error message>

Now for the error message themselves. Stylistically, a few points. The sentence 'begins' with the other information, so they always begin with a lower case letter, and end with a full stop.

    errors.md:29:1: error: encountered demonstrative error message.

It probably won't come up, but prefer British spelling. In particular, 'initialise', not 'initialize'.

Remember that error messages are preceded by the word 'error' or 'warning' (when the user can do something about them) so they should be phrased in terms of what is wrong; do *not* just point out what the user has done. For example:

    module a;
    void foo() { 
        void bar() {
            void baz() {
            } 
        }
    }

 If the compiler prints "a.volt:4:8: error: function nested within another nested function." in response to this, the user is going to become frustrated. They *know* the function has been nested within another nested function, they wrote the code. Prefer instead "a.volt:4:8: error: functions may not be nested within another nested function." Figuring out where *what* they did wrong should be made easy by accurate location information, the message is for telling them *why* what they did is an error.

 Of course, describing what went wrong isn't always bad style, especially if it's obvious to the compiler but not to the programmer: "unidentified variable 'playar'." This is technically simply descriptive, but is clearly better than the tortuous "variables like 'playar' must be declared before use." Use your common sense, and put yourself in the shoes of a tired programmer at four in the afternoon on a Friday -- what is going to get the point across best to that person?

 Always couch names of things from the user's code (type names, function names, etc) in single quote marks. Certain names may make the error messages hard to read otherwise.

 In the rush of adding a feature or fixing bugs, often times poor error messages can be added that disobey these rules. Do not be shy in filing bugs or pull requests to fix error message messages or locations -- these are incredibly valuable, and very welcome.
