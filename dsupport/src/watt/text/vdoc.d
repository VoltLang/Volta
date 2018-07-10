module watt.text.vdoc;

import watt.text.utf;

/*!
 * Take a doc comment and remove comment cruft from it.
 */
string cleanComment(string comment, out bool isBackwardsComment)
{
	char[] output;

	if (comment.length < 2) {
		return comment;
	}

	char commentChar;
	if (comment[0..2] == "*!") {
		commentChar = '*';
	} else if (comment[0..2] == "+!") {
		commentChar = '+';
	} else if (comment[0..2] == "/!") {
		commentChar = '/';
	} else {
		return comment;
	}

	uint whiteCal = uint.max;
	uint whiteNum = 1u; // One extra
	bool calibrating = true;
	bool ignoreWhitespace = true;
	foreach (i, dchar c; comment) {
		if (i == comment.length - 1 && commentChar != '/' && c == '/') {
			continue;
		}

		if (i == 2 && c == '<') {
			isBackwardsComment = true;
		}

		switch (c) {
		case '<':
			if (whiteNum < whiteCal) {
				whiteNum += 1;
				break;
			}
			goto default;
		case '!':
			if (whiteNum < whiteCal) {
				whiteNum += 1;
				break;
			}
			goto default;
		case '*', '+', '/':
			if (c == commentChar && ignoreWhitespace) {
				whiteNum += 1;
				break;
			}
			goto default;
		case '\t':
			whiteNum += 7;
			goto case;
		case ' ':
			whiteNum += 1;
			if (!ignoreWhitespace || whiteNum > whiteCal) {
				goto default;
			}
			break;
		case '\n':
			ignoreWhitespace = true;
			encode(output, '\n');
			whiteNum = 0;
			break;
		default:
			if (calibrating) {
				whiteCal = whiteNum;
				calibrating = false;
			}
			ignoreWhitespace = false;
			encode(output, c);
			break;
		}
	}

	return cast(string) output;
}
