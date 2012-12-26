// Copyright © 2010-2011, Bernard Helyer.  All rights reserved.
// Copyright © 2011, Jakob Ovrum.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module runner;

import std.algorithm : split, sort;
import std.process : system;
import std.string : format;
import std.stdio : stderr, stdout, readln;
import std.file : exists, mkdir, remove, File, globMatch, DirEntry, dirEntries, SpanMode;
import std.path : dirName, baseName, dirSeparator, stripExtension;
import std.conv : to;


/*
 * TODO
 *
 * Save output a text file for each test.
 * Run tests concurrently.
 * Hook up dependencies.
 */

void main(string[] args)
{
	string compiler = ".." ~ dirSeparator ~ "volt";
	bool waitOnExit;
	bool printOk;
	bool printImprovments = true;
	bool printFailing;
	bool printRegressions = true;

	foreach(arg; args[1 .. $]) {
		switch(arg) {
		case "--print-all":
			printOk = true;
			printImprovments = true;
			printFailing = true;
			printRegressions = true;
			break;
		case "--print-ok":
			printOk = true;
			goto case;
		case "--print-improvments":
			printImprovments = true;
			break;
		case "--print-failing":
			printFailing = true;
			goto case;
		case "--print-regressions":
			printRegressions = true;
			break;
		default:
		}
	}

	string[] tests;
	int testNumber;
	int passed = 0;
	int regressions = 0;
	int improvments = 0;


	/*
	 * Find tests to run.
	 */


	void addTest(string file) {
		testNumber++;
		tests ~= file;
	}

	if (true) {
		listDir("simple", "*test_*.d", &addTest);
		listDir("cond", "*test_*.d", &addTest);
		listDir("imports", "*test_*.d", &addTest);
		listDir("aggregate", "*test_*.d", &addTest);
	}
	sort(tests);

	/*
	 * Do testing run.
	 */

	foreach(test; tests) {
		try {
			runTest(test, compiler);
		} catch (TestOk ok) {
			passed++;
			improvments += !ok.hasPassed;
			if (printOk || !ok.hasPassed && printImprovments)
				stdout.writeln(ok.msg);
		} catch (TestException e) {
			if (printFailing || e.hasPassed && printRegressions)
				stdout.writeln(e.msg);
			regressions += e.hasPassed;
		}
	}


	/*
	 * Print summary.
	 */

	
	stdout.writefln("Summary: %s tests, %s pass%s, %s failure%s, %.2f%% pass rate, "
	         "%s regressions, %s improvements.",
	         testNumber, passed, passed == 1 ? "" : "es", 
	         testNumber - passed, (testNumber - passed) == 1 ? "" : "s", 
	         (cast(real)passed / testNumber) * 100,
	         regressions, improvments);

	if (waitOnExit) {
		stdout.writeln("Press any key to exit...");
		readln();
	}
}

/**
 * Returns if the test has passed in the past.
 */
void runTest(string filename, string compiler)
{
	string[] dependencies;
	bool hasPassed = true;
	bool expectedToCompile = true;
	int expectedRetval = 0;


	/*
	 * Read test directives from test.
	 */


	auto f = File(filename, "r");
	foreach (line; f.byLine) {
		if (line.length < 3 || line[0 .. 3] != "//T") {
			continue;
		}

		auto words = split(line);
		if (words.length != 2) {
			stderr.writefln("%s: malformed test.", filename);
			throw new MalformedTest(filename, hasPassed);
		}

		auto set = split(words[1], ":");
		if (set.length < 2) {
			stderr.writefln("%s: malformed test.", filename);
			throw new MalformedTest(filename, hasPassed);
		}

		auto var = set[0].idup;
		auto val = set[1].idup;

		switch (var) {
		case "compiles":
			expectedToCompile = getBool(val);
			break;
		case "retval":
			expectedRetval = getInt(val);
			break;
		case "dependency":
			dependencies ~= val;
			break;
		case "has-passed":
			hasPassed = getBool(val);
			break;
		default:
			throw new MalformedTest(filename, hasPassed);
		}
	}
	f.close();


	/*
	 * Run the test.
	 */


	string justTest = stripExtension(filename);
	string inDir = dirName(filename);
	string outDir = ".obj" ~ dirSeparator ~ justTest;
	string exeName = outDir ~ dirSeparator ~ "output.exe";
	string command = compiler ~ " -o " ~ exeName;

	foreach (d; dependencies) {
		command ~= " " ~ inDir ~ dirSeparator ~ d;
	}
	command ~= " " ~ filename;

	mkdirP(outDir);

	if (exists(exeName))
		remove(exeName);

	auto retval = system(command);

	// Catch segfaults and ICEs
	if (retval != 0 && retval != 1)
		throw new CompilationPanic(filename, hasPassed);

	if (expectedToCompile && retval != 0)
		throw new CompilationFailed(filename, hasPassed);

	if (!expectedToCompile && retval == 0)
		throw new CompilationSucceeded(filename, hasPassed);

	if (!expectedToCompile && retval != 0)
		throw new TestOk(filename, hasPassed);

	retval = system(exeName);

	if (retval != expectedRetval && expectedToCompile)
		throw new BadRetval(filename, hasPassed, retval, expectedRetval);

	throw new TestOk(filename, hasPassed);
}


/*
 *
 * Exceptions.
 *
 */


class TestResult : Exception
{
	string test;
	bool passed;
	bool hasPassed;

	this(string test, bool passed, bool hasPassed, string str)
	{
		this.test = test;
		this.passed = passed;
		this.hasPassed = hasPassed;

		auto t = format("%s: %s.", test, str);
		super(t);
	}
}

class TestOk : TestResult
{
	this(string test, bool hasPassed)
	{
		super(test, true, hasPassed, "ok");
	}
}

class TestException : TestResult
{
	this(string test, bool hasPassed, string str)
	{
		super(test, false, hasPassed, str);
	}
}

class MalformedTest : TestException
{
	this(string test, bool has) { super(test, has, "malformed test"); }
}

class CompilationFailed : TestException
{
	this(string test, bool has) { super(test, has, "test expected to compile, did not"); }
}

class CompilationPanic : TestException
{
	this(string test, bool has) { super(test, has, "compile returned invalid retval"); }
}

class CompilationSucceeded : TestException
{
	this(string test, bool has) { super(test, has, "test expected to not compile, did"); }
}

class BadRetval : TestException
{
	int retval;
	int expectedRetval;

	this(string test, bool has, int retval, int expected)
	{
		this.retval = retval;
		this.expectedRetval = expected;

		auto str = format("test return wrong value %s, expected %s", retval, expected);
		super(test, has, str);
	}
}


/*
 *
 * Utils
 *
 */


/**
 * Searches @dir for files matching pattern, foreach found
 * calls the given delegate with its name.
 */
void listDir(string dir, string pattern, void delegate(string file) dg)
{
	foreach(ref DirEntry de; dirEntries(dir, SpanMode.breadth)) {
		if (de.isDir) {
			continue;
		} else if (!globMatch(de.name, pattern)) {
			continue;
		}

		dg(de.name);
	}
}

/**
 * Does the same as unix's "mkdir -p" command.
 */
void mkdirP(string name)
{
	if (name == "" || name is null)
		return;

	auto str = dirName(name);
	if (str != ".")
		mkdirP(str);

	if (!exists(name))
		mkdir(name);
}

/**
 * Used for parsing test directives, that are bool types.
 */
bool getBool(string s)
{
	return s == "yes";
}

/**
 * Used for parsing test directives, that are int types.
 */
int getInt(string s)
{
	return to!int(s);
}
