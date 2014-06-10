package furusystems.console;
import hscript.Expr;
import hscript.Parser;

/**
 * ...
 * @author Andreas Rønning
 */
typedef ValueDef = { type:ValueType, value:Dynamic, parsedExpr:Expr };
class ParseUtils
{
	static var numberEreg:EReg = ~/-*[0-9]+[.,]*[0-9]*/;
	static var listEreg:EReg = ~/^\[.+,?+\]$/;
	static var urlEreg:EReg = ~/\b(http:\/\/)/;
	
	static var parser:Parser = new Parser();
	public static inline function parse(str:String):Expr {
		return parser.parseString(str);
	}
	public static function toValue(value:String):ValueDef 
	{
		var out:ValueDef = { value:null, type:ValueType.NULL, parsedExpr:null };
		if (value == "null" || value == null || value == "") {
			out.type = NULL;
			return out;
		}
		if (value.toLowerCase() == "true" || value.toLowerCase() == "false") {
			out.type = BOOLEAN;
			out.value = value.toLowerCase() == "true";
			return out;
		}
		if (urlEreg.match(value) && urlEreg.matchedPos().len == value.length) {
			out.type = URL;
		}else if ((listEreg.match(value) && listEreg.matchedPos().len == value.length) || value == "[]") {
			out.type = LIST;
			out.value = toList(value);
		}else if (numberEreg.match(value) && numberEreg.matchedPos().len == value.length) { 
			out.type = NUMBER;
			out.value = Std.parseFloat(value);
		} else {
			var e:Expr;
			if (value.indexOf(";") > -1){  //LOLPARSE
				try {
					e = parse(value.toLowerCase());
					out.type = SCRIPT;
					out.parsedExpr = e;
				}catch (error:Dynamic) {
					out.type = STRING;
				}
			}else {
				out.type = STRING;
			}
			out.value = value;
		}
		return out;
	}
	public static function toList(value:String):Array<Dynamic> 
	{
		var out:Array<Dynamic> = [];
		if (value == "[]") return out;
		var split = value.substring(1, value.length - 1).split(",");
		for (s in split) {
			if (numberEreg.match(s) && numberEreg.matchedPos().len == s.length) {
				out.push(Std.parseFloat(s));
			}else if (s.toLowerCase() == "true") {
				out.push(true);
			}else if (s.toLowerCase() == "false") {
				out.push(false);
			}else {
				out.push(s);
			}
		}
		return out;
	}
	
}