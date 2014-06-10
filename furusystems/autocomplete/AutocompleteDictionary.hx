package furusystems.autocomplete;

/**
 * ...
 * @author Andreas Roenning
 */
using Lambda;
class AutocompleteDictionary {
	public var basepage:Dynamic;
	//var stringContents:Array<String>;
	var stringContentsLowercase:Map<String,String>;
	var numItems:Int;
	public function new() {
		basepage = { };
		//stringContents = [];
		stringContentsLowercase = new Map<String,String>();
	}
	
	public function correctCase(str:String):String {
		var result = stringContentsLowercase.get(str.toLowerCase());
		if (result != null) return result;
		throw "No result";
	}
	
	public inline function addToDictionary(str:String):Void {
		stringContentsLowercase.set(str.toLowerCase(), str); 
		var strParts = str.split("");
		strParts.push("");
		insert(strParts, basepage);
		numItems++;
	}
	
	public function contains(str:String):Bool {
		return stringContentsLowercase.exists(str.toLowerCase());
	}
	
	inline function insert(parts:Array<String>, page:Dynamic):Void {
		if (!(parts.length == 0 || parts[0] == null)) { 
			var letter:String = parts[0];
			if (!Reflect.hasField(page, letter)) {
				Reflect.setField(page, letter, { } );
			}
			insert(parts.slice(1, parts.length), Reflect.field(page, letter));
		}
	}
	
	public function getSuggestion(arr:Array<String>):String {
		var suggestion = "";
		var len = arr.length;
		var tmpDict = basepage;
		
		if (len < 1) {
			return suggestion;
		}
		
		for (letter in arr) {
			if (Reflect.hasField(tmpDict, letter.toUpperCase()) && Reflect.hasField(tmpDict, letter.toLowerCase())) {
				var upperTmpDict:Dynamic = Reflect.field(tmpDict, letter.toUpperCase());
				var lowerTmpDict:Dynamic = Reflect.field(tmpDict, letter.toLowerCase());
				tmpDict = mergeDictionaries(lowerTmpDict, upperTmpDict);
			} else if (Reflect.hasField(tmpDict, letter.toUpperCase())) {
				tmpDict = Reflect.field(tmpDict, letter.toUpperCase());
			} else if (Reflect.hasField(tmpDict, letter.toLowerCase())) {
				tmpDict = Reflect.field(tmpDict, letter.toLowerCase());
			} else {
				return suggestion;
			}
		}
		
		var loop = true;
		while (loop) {
			loop = false;
			for (l in Reflect.fields(tmpDict)) {
				if (shouldContinue(tmpDict)) {
					suggestion += l;
					tmpDict = Reflect.field(tmpDict, l);
					loop = true;
					break;
				}
			}
		}
		
		return suggestion;
	}
	
	inline function mergeDictionaries(lowerCaseDict:Dynamic, upperCaseDict:Dynamic):Dynamic {
		var tmpDict = { };
		
		for (j in Reflect.fields(lowerCaseDict)) {
			Reflect.setField(tmpDict, j, Reflect.field(lowerCaseDict, j));
		}
		
		for (k in Reflect.fields(upperCaseDict)) {
			if (Reflect.hasField(tmpDict, k) && Reflect.hasField(upperCaseDict, k)) {
				Reflect.setField(tmpDict, k, mergeDictionaries(Reflect.field(tmpDict, k), Reflect.field(upperCaseDict, k)));
			} else {
				Reflect.setField(tmpDict, k, Reflect.field(upperCaseDict, k));
			}
		}
		return tmpDict;
	}
	
	inline function shouldContinue(tmpDict:Dynamic):Bool {
		var count = 0;
		var result:Bool = true;
		for (k in Reflect.fields(tmpDict)) {
			if (count > 0) {
				result = false;
				break;
			}
			count++;
		}
		return result;
	}
	
	public function toString():String {
		return "Dictionary of " + numItems + " length";
	}

}