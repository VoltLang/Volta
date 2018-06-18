//! Associate paths with module names.
module vls.util.pathTree;

import text = watt.text.string;

unittest
{
	tree: PathTree;
	tree.set("foo", "hello");
	tree.set("foo.bar", "world");
	assert(tree.get(["foo"]) == "hello");
	assert(tree.get(["foo", "bar"]) == "world");
	assert(tree.get(["food", "bar"]) is null);
	assert(tree.get(["foo", "baz"]) == "hello");
	assert(tree.get(["foo", "bar", "baz"]) == "world");
}

/*!
 * The user can set a specific module name chain to
 * a certain path.
 *
 * Say, `"foo.bar": "/path/to/foobar/src".  
 * Then the import `foo.bar.bab` would look 
 * for `/path/to/foobar/src/foo/bar/bab.volt`.
 */
struct PathTree
{
private:
	mRoot: PathNode*;

public:
	/*!
	 * Associate `path` with `name`.
	 *
	 * Where `name` is an identifier, or identifiers
	 * separated by `.` characters.
	 */
	fn set(name: string, path: string)
	{
		names := text.split(name, '.');
		set(names, path);
	}

	/*!
	 * Associate `path` with a given module name.
	 */
	fn set(names: string[], path: string)
	{
		if (mRoot is null) {
			mRoot = PathNode.createNode();
		}
		current := mRoot;
		foreach (i, name; names) {
			isPackage := i < names.length - 1;
			if (isPackage) {
				current = getNode(current, name);
			} else {
				setPath(current, name, path);
			}
		}
	}

	/*!
	 * Get a path associated with the given module name, if any.
	 *
	 * Doesn't check every name portion, just as many leading
	 * packages to get a path. This lets the user set a different
	 * path for `foo.bar` and `foo.baz`, say.
	 *
	 * @Returns: The path associated with the given name, or `null`.
	 */
	fn get(names: string[]) string
	{
		current := mRoot;
		lastName: string = null;

		while (names.length > 0) {
			name := names[0];
			names = names[1 .. $];
			p := name in current.children;
			if (p is null) {
				return lastName;
			}
			current = *p;
			lastName = current.path;
		}
		if (names.length == 0 && current !is null) {
			return current.path;
		}
		return lastName;
	}

private:
	fn getNode(root: PathNode*, name: string) PathNode*
	{
		p: PathNode** = name in root.children;
		if (p !is null) {
			return *p;
		}
		node := PathNode.createNode();
		root.children[name] = node;
		return node;
	}

	fn setPath(root: PathNode*, name: string, path: string)
	{
		root.children[name] = PathNode.createPath(path);
	}
}

private:

struct PathNode
{
public:
	global fn createNode() PathNode*
	{
		node := new PathNode;
		return node;
	}

	global fn createPath(path: string) PathNode*
	{
		node := PathNode.createNode();
		node.path = path;
		return node;
	}

public:
	children: PathNode*[string];
	path: string;
}
