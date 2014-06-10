package furusystems.autocomplete;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.text.TextField;
import flash.ui.Keyboard;
import haxe.Timer;

/**
 * ...
 * @author Andreas Rønning
 * Based on Ali Mills' work on ternary trees at http://www.asserttrue.com/articles/2006/04/09/actionscript-projects-in-flex-builder-2-0
 */
using Lambda;
class AutocompleteManager {
	
	var txt:String;
	var paused:Bool = false;
	var _targetTextField:TextField;
	var delay:Timer;
	public var targetTextField(get, set):TextField;
	public var dict:AutocompleteDictionary;
	public var suggestionActive:Bool = false;
	public var ready:Bool = false;
	public var delimiters:Array<String>;
	public function new(targetTextField:TextField) {
		this.targetTextField = targetTextField;
		delimiters = [];
	}
	
	public function setDictionary(newDict:AutocompleteDictionary):Void {
		dict = newDict;
		ready = dict != null;
	}
	
	function changeListener(e:Event):Void {
		if (!ready) return;
		if (delay != null) delay.stop();
		suggestionActive = false;
		if (!paused) {
			delay = Timer.delay(complete.bind(delimiters), 33);
		}
	}
	
	function keyDownListener(e:KeyboardEvent):Void {
		if (!ready) return;
		if (e.keyCode == Keyboard.BACKSPACE || e.keyCode == Keyboard.DELETE) {
			paused = true;
		} else {
			paused = false;
		}
	}
	
	public function complete(?delimiters:Array<String>):Void {
		//TODO: Start process offset by the nearest occurence of an opening parenthesis
		suggestionActive = false;
		//if the caret is somewhere in an existing word, ignore
		var nextChar:String = _targetTextField.text.charAt(_targetTextField.caretIndex);
		if (_targetTextField.caretIndex < _targetTextField.text.length && nextChar != "" && nextChar != " ") {
			return;
		}
		
		//we only complete single words, so start caret is the beginning of the word the caret is currently in
		var firstIndex = getFirstIndexOfWordAtCaretIndex(_targetTextField, delimiters);
		var str = _targetTextField.text.substr(firstIndex, _targetTextField.caretIndex);
		var strParts = str.split("");
		var suggestion:String = "";
		//if (firstIndex < 1) {
			suggestion = dict.getSuggestion(strParts);
		//}
		if (suggestion.length > 0) {
			//Sort of a brutal divide and conquer strategy here. Someone smarter take a look?
			var _originalText:String = _targetTextField.text;
			var originalCaretIndex:Int = _targetTextField.caretIndex;
			var currentWord:String = getWordAtCaretIndex(_targetTextField);
			var wordSplit = _originalText.split(" ");
			var wordIndex:Int = wordSplit.indexOf(currentWord);
			currentWord += suggestion;
			wordSplit.splice(wordIndex, 1);
			wordSplit.insert(wordIndex, currentWord);
			_targetTextField.text = wordSplit.join(" ");
			
			_targetTextField.setSelection(originalCaretIndex, originalCaretIndex + suggestion.length);
			suggestionActive = true;
		}
	}
	
	public static inline function getNextSpaceAfterCaret(tf:TextField):Int {
		var str:String = tf.text;
		var first:Int = str.lastIndexOf(" ", tf.caretIndex) + 1;
		var last:Int = str.indexOf(" ", first);
		if (last < 0)
			last = tf.text.length;
		return last;
	}
	
	public static inline function selectWordAtCaretIndex(tf:TextField):Void {
		var str:String = tf.text;
		var first:Int = str.lastIndexOf(" ", tf.caretIndex) + 1;
		var last:Int = str.indexOf(" ", first);
		if (last == -1)
			last = str.length;
		tf.setSelection(first, last);
	}
	
	public static inline function getWordAtCaretIndex(tf:TextField, ?delimiters:Array<String>):String {
		return getWordAtIndex(tf, tf.caretIndex, delimiters);
	}
	
	public static inline function getWordAtIndex(tf:TextField, index:Int, ?delimiters:Array<String>):String {
		if (tf.text.charAt(tf.caretIndex) == " ") {
			index--; //We want the word behind the current space, not the next one
		}
		var str:String = tf.text;
		var highestIndex:Int = -99999999;
		var li:Int = str.lastIndexOf(" ", index);
		li = highestIndex = cast Math.max(li, highestIndex);
		if(delimiters!=null){
			for (d in delimiters) {
				var nd = str.lastIndexOf(d, index);
				if (nd > highestIndex) {
					highestIndex = li = nd;
				}
			}
		}
		//var li:Int = str.lastIndexOf(" ", index);
		var first:Int = li + 1;
		var last:Int = str.indexOf(" ", first);
		if (last == -1) {
			last = str.length;
		}
		return str.substring(first, last);
	}
	
	public static inline function getFirstIndexOfWordAtCaretIndex(tf:TextField, ?delimiters:Array<String>):Int {
		var wordAtIndex:String = getWordAtCaretIndex(tf, delimiters);
		var str:String = tf.text;
		return str.lastIndexOf(wordAtIndex, tf.caretIndex);
	}
	
	public static inline function getLastIndexOfWordAtCaretIndex(tf:TextField):Int {
		var wordAtIndex:String = getWordAtCaretIndex(tf);
		var str:String = tf.text;
		return str.indexOf(wordAtIndex, tf.caretIndex) + wordAtIndex.length;
	}
	
	public static inline function getCaretDepthOfWord(tf:TextField):Int {
		//var word:String = getWordAtCaretIndex(tf);
		var wordIndex:Int = getFirstIndexOfWordAtCaretIndex(tf);
		return tf.caretIndex - wordIndex;
	}
	
	public function isKnown(str:String):Bool {
		return dict.contains(str);
	}
	
	function get_targetTextField():TextField {
		return _targetTextField;
	}
	
	function set_targetTextField(value:TextField):TextField {
		try {
			_targetTextField.removeEventListener(Event.CHANGE, changeListener);
			_targetTextField.removeEventListener(KeyboardEvent.KEY_DOWN, keyDownListener);
		} catch (e:Dynamic) {
		}
		_targetTextField = value;
		_targetTextField.addEventListener(Event.CHANGE, changeListener);
		_targetTextField.addEventListener(KeyboardEvent.KEY_DOWN, keyDownListener);
		return _targetTextField;
	}
	
	public function correctCase(str:String):String {
		try {
			return dict.correctCase(str);
		} catch (e:Dynamic) {
			return str;
		}
	}
}