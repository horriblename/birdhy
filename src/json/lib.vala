// json-glib kept segfaulting me so here we are
// Parses json into a Dict, nothing more, I'm tired of this shit
// I'm not gonna look at the spec so there's gonna be problems, but truly, idgaf
// Performance is gonna be so terrible with 10000000000000 string allocations but fuck it
namespace Birdhy.JSON {

public errordomain ParseError {
	MISSING_CLOSING_DOUBLE_QUOTE,
	UNEXPECTED_SYMBOL,
	EXPECTED_OBJECT_KEY,
	EXPECTED_COMMA,
	EXPECTED_COLON,
	EXPECTED_NUMBER,
	EXPECTED_EOF,
}

class Tokenizer {
	string input;
	int pos;
	string? saved;

	public Tokenizer(string input) {
		this.input = input;
	}

	// outputs the next token, or empty string if at EOF
	public string next() throws ParseError {
		if (this.saved != null) {
			var saved = this.saved;
			this.saved = null;
			return saved;
		}

		this.skip_whitespace();
		if (this.pos >= this.input.length) {
			return "";
		}
		switch (this.input[this.pos]) {
			case '{':
			case '}':
			case '[':
			case ']':
			case ':':
			case ',':
				var start = this.pos;
				this.pos++;
				return this.input[start : this.pos];
			case '"':
				return this.next_string();
			case '-':
				if (this.pos + 1 >= this.input.length) {
					throw new ParseError.EXPECTED_NUMBER(@"Expected number after '-' near: $(this.input[this.pos:])");
				}
				this.pos++;
				return "-" + this.next_number();

			default:
				if (this.input[this.pos].isdigit()) {
					return this.next_number();
				} else if (this.input[this.pos].isalpha()) {
					return this.next_word();
				}

			throw new ParseError.UNEXPECTED_SYMBOL(@"Unexpected char: $(this.input[this.pos])");
		}
	}

	public string peek() throws ParseError {
		return this.saved ?? (this.saved = this.next());
	}

	string next_word() {
		assert(this.input[this.pos].isalpha());
		int start = this.pos;
		while(this.pos < input.length && this.input[this.pos].isalpha()) {
			this.pos++;
		}
		return this.input[start : this.pos];
	}

	string next_string() throws ParseError {
		assert(this.input[this.pos] == '"');
		int curr = this.pos+1;
		
		for (; curr < input.length; curr++) {
			if (this.input[curr] == '"' && this.input[curr-1] != '\\') {
				var ret = this.input[this.pos:curr+1];
				this.pos = curr + 1;
				return ret;
			}
		}
		
		throw new ParseError.MISSING_CLOSING_DOUBLE_QUOTE("Missing closing double quote");
	}

	string next_number() throws ParseError {
		var init = this.pos;
		assert(this.input[init].isdigit());
		while(this.pos < this.input.length && this.input[this.pos].isdigit()) {
			this.pos++;
		}

		return this.input[init : this.pos];
	}

	void skip_whitespace() {
		while(this.pos < this.input.length && this.input[this.pos].isspace()) {
			this.pos++;
		}
	}
}

public Value parse_json(string input) throws ParseError {
	var tok = new Tokenizer(input);
	var res = parse(tok);
	var next = tok.next();
	if (next != "")  {
		throw new ParseError.EXPECTED_EOF(@"Expected EOF, got $next");
	}
	return res;
}

Value parse(Tokenizer tok) throws ParseError {
	string? next = tok.next();
	switch (next[0]) {
	case '{':
		return parse_object(tok);
	case '[':
		return parse_array(tok);
	case '"':
		return new String(next[1:-1]);
	case '-':
		return new Int(int.parse(next));
	default:
		if (next[0].isdigit()) {
			return new Int(int.parse(next));
		}
		if (next == "null") {
			return new Null();
		}
		if (next == "true") {
			return new Bool(true);
		}
		if (next == "false") {
			return new Bool(false);
		}
		break;
	}

	throw new ParseError.UNEXPECTED_SYMBOL(@"Unexpected symbol: $next");
}

Value parse_object(Tokenizer tok) throws ParseError {
	string next, key;
	var obj = new Gee.HashMap<string, Value>(null, null, null);

	if (tok.peek() == "}") {
		tok.next();
		return new Dict(obj);
	}

	while (true) {
		key = tok.next();
		// TODO: parse number keys
		if (key[0] != '"') {
			throw new ParseError.EXPECTED_OBJECT_KEY(@"Expected an object key, got: $key");
		}
		
		next = tok.next();
		if (next != ":") {
			throw new ParseError.EXPECTED_COLON(@"Expected colon, got: $next");
		}

		print("parsed colon");
		obj.set(key[1:-1] /*trim quotes*/, parse(tok));

		next = tok.next();
		if (next == "}") {
			return new Dict(obj);
		} else if (next != ",") {
			throw new ParseError.EXPECTED_COMMA(@"Expected comma, got: $next");
		}
	}
}

Value parse_array(Tokenizer tok) throws ParseError {
	string next;
	if (tok.peek() == "]") {
		tok.next();
		return new Array(new Value[0]);
	}
	var list = new Gee.ArrayList<Value>();

	while (true) {
		list.add(parse(tok));

		next = tok.next();
		if (next == "]") {
			break;
		} else if (next != ",") {
			throw new ParseError.EXPECTED_COMMA(@"Expected comma, got: $next");
		}
	}

	return new Array(list.to_array());
}

public errordomain TypeError {
	INVALID_TYPE,
}

public class Int : Value {
	public int n;
	public Int(int n) {
		this.n = n;
	}
}

public class Bool : Value {
	public bool b;
	public Bool(bool b) {
		this.b = b;
	}
}

public class String : Value {
	public string s;
	public String(string s) {
		this.s = s;
	}
}

public class Array : Value {
	public Value[] arr;
	public Array(Value[] arr) {
		this.arr = arr;
	}
}

public class Dict : Value {
	public Gee.Map<string, Value> dict;
	public Dict(Gee.Map<string, Value> dict) {
		this.dict = dict;
	}
}

public class Null : Value {
	public Null() {}
}

public class Value : GLib.Object {

	public string get_string() throws TypeError {
		var s = this as String;
		if (s == null) {
			throw new TypeError.INVALID_TYPE(@"Trying to get string, got something else");
		}
		return ((!) s).s;
	}

	public bool get_bool() throws TypeError {
		var b = this as Bool;
		if (b == null) {
			throw new TypeError.INVALID_TYPE(@"Trying to get bool, got something else");
		}
		return ((!) b).b;
	}

	public int get_int() throws TypeError {
		var i = this as Int;
		if (i == null) {
			throw new TypeError.INVALID_TYPE(@"Trying to get int, got something else");
		}
		return ((!) i).n;
	}

	public Value[] get_array() throws TypeError {
		var a = this as Array;
		if (a == null) {
			throw new TypeError.INVALID_TYPE(@"Trying to get array, got something else");
		}
		return ((!) a).arr;
	}

	public Gee.Map<string, Value> get_dict() throws TypeError {
		var dict = this as Dict;
		if (dict == null) {
			throw new TypeError.INVALID_TYPE(@"Trying to get dict, got something else");
		}
		return ((!) dict).dict;
	}
}

public void debug_token(string s) {
	var tok = new Tokenizer(s);
	for (var next = tok.next(); next != ""; next = tok.next()) {
		print(@"token: $next\n");
	}
}

}
