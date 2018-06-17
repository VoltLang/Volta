//! Associate paths with module names.
module vls.util.pathTree;

import text = watt.text.string;


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
		nameIndex: size_t;
		current := mRoot;
		while (current !is null && nameIndex < names.length) {
			if (current.type == PathType.Path) {
				return current.u.path;
			} else {
				current = current.u.children[names[nameIndex++]];
			}
		}
		if (current !is null && current.type == PathType.Path) {
			return current.u.path;
		}
		return null;
	}

private:
	fn getNode(root: PathNode*, name: string) PathNode*
	{
		p: PathNode** = name in root.u.children;
		if (p !is null && (*p).type == PathType.Node) {
			return *p;
		}
		node := PathNode.createNode();
		root.u.children[name] = node;
		return node;
	}

	fn setPath(root: PathNode*, name: string, path: string)
	{
		root.u.children[name] = PathNode.createPath(path);
	}
}

private:

enum PathType
{
	Node,
	Path,
}

union PathUnion
{
	children: PathNode*[string];
	path: string;
}

struct PathNode
{
public:
	global fn createNode() PathNode*
	{
		node := new PathNode;
		node.type = PathType.Node;
		return node;
	}

	global fn createPath(path: string) PathNode*
	{
		node := new PathNode;
		node.type = PathType.Path;
		node.u.path = path;
		return node;
	}

public:
	type: PathType;
	u:    PathUnion;
}
