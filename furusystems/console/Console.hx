package furusystems.console;
#if air3
import flash.desktop.NativeApplication;
#end
import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.filters.DropShadowFilter;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.ui.Keyboard;
import flash.utils.IDataOutput;
import furusystems.autocomplete.AutocompleteDictionary;
import furusystems.autocomplete.AutocompleteManager;
import haxe.Log;
import haxe.PosInfos;
import haxe.xml.Fast;
using furusystems.console.ParseUtils;
/**
 * ...
 * @author Andreas Rønning
 */
enum LogLevel {
	SYSTEM;
	NORMAL;
	WARNING;
	ERROR;
}
class Line {
	public var level:LogLevel;
	public var str:String;
	public inline function new(str:String, level:LogLevel) {
		this.level = level;
		this.str = str;
	}
}
class Console extends Sprite
{
	var outField:TextField;
	var inField:TextField;
	var lines:Array<Line>;
	var scrollPos:Int = 0;
	var history:Array<String>;
	var autoComplete:AutocompleteManager;
	var commands:Map<String,Dynamic>;
	var commandHelp:Map<String,String>;
	var dict:AutocompleteDictionary;
	static var normalFmt = new TextFormat("_typewriter", 12, 0xbbbbbb);
	static var systemFmt = new TextFormat("_typewriter", 12, 0x00bb00);
	static var errorFmt = new TextFormat("_typewriter", 12, 0xbb0000);
	static var warnFmt = new TextFormat("_typewriter", 12, 0xF18856);
	var _atBottom:Bool;
	var dims:Rectangle;
	public function new() 
	{
		super();
		_atBottom = true;
		commands = new Map<String,Dynamic>();
		commandHelp = new Map<String,String>();
		addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		//#if !debug
		Log.trace = trace;
		//#end
		outField = new TextField();
		outField.backgroundColor = 0x111111;
		outField.background = true;
		inField = new TextField();
		inField.background = true;
		inField.backgroundColor = 0;
		addChild(outField);
		addChild(inField);
		history = [];
		outField.defaultTextFormat = normalFmt;
		inField.height = 20;
		inField.defaultTextFormat = new TextFormat("_typewriter", 12, 0x44bb44);
		inField.type = TextFieldType.INPUT;
		inField.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 9999);
		filters = [new DropShadowFilter(2, 90)];
		clear();
		
		#if air3
		var desc = NativeApplication.nativeApplication.applicationDescriptor;
		var f = new Fast(Xml.parse(desc.toXMLString()).firstChild());
		var ver:String = "";
		var name:String = "";
		for (n in f.elements) {
			if (n.name == "versionNumber") {
				ver = n.innerData;
				break;
			}else if (n.name == "id") {
				name = n.innerData;
			}
		}
		trace(name.split(".").pop() + " v." + ver, null);
		#end
		addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
		autoComplete = new AutocompleteManager(inField);
		dict = new AutocompleteDictionary();
		autoComplete.setDictionary(dict);
		
		createCommand("help", showHelp, "Show this help");
		createCommand("clear", clear, "Clear the console");
	}
	
	function onAddedToStage(e:Event):Void 
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onTabCheck,true,9999);
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
	}
	
	function onTabCheck(e:KeyboardEvent):Void 
	{
		if (e.keyCode == Keyboard.TAB && visible) {
			e.preventDefault();
			e.stopPropagation();
			e.stopImmediatePropagation();
			stage.focus = inField;
			inField.setSelection(inField.text.length, inField.text.length);
		}else if (e.keyCode == Keyboard.ESCAPE) {
			if (visible = !visible) {				
				stage.focus = inField;
				inField.setSelection(inField.text.length, inField.text.length);
			}
		}else if (e.keyCode == Keyboard.PAGE_UP && visible) {
			scroll( numLinesVisible());
		}else if (e.keyCode == Keyboard.PAGE_DOWN && visible) {
			scroll( -numLinesVisible());
		}
	}
	
	function onKeyDown(e:KeyboardEvent):Void 
	{
		e.stopPropagation();
		if (e.keyCode == Keyboard.ENTER) {
			if (inField.text.length > 0) {
				#if !debug 
				try { 
				#end
					trace("<< " + inField.text, SYSTEM);
					var result = execute(inField.text); 
					if (result != "" && result!=null) trace(">> "+result, null);
				#if !debug
				}catch (e:Dynamic) {
					trace("" + e, ERROR);
				}
				#end
				inField.text = "";
			}
		}else if (e.keyCode == Keyboard.BACKSPACE) {
			e.stopPropagation();
		}else if (e.keyCode == Keyboard.UP) {
			if (history.length > 0) {
				e.preventDefault();
				inField.text = history.pop();
				inField.setSelection(0, inField.text.length);
			}
		}
	}
	inline function getTokens(str:String):Array<Token> {
		var out:Array<Token> = [];
		for (item in str.split(" ")) {
			var def = item.toValue();
			switch(def.type) {
				case URL | STRING:
					out.push(STRING(def.value));
				case SCRIPT:
					out.push(SCRIPT(def.value));
				case NUMBER:
					out.push(FLOAT(def.value));
				case NULL:
					out.push(NULL);
				case LIST:
					out.push(LIST(def.value));
				case BOOLEAN:
					out.push(BOOL(def.value));
			}
			//out.push(new Token(item));
		}
		return out;
	}
	
	public function createCommand(str:String, func:Dynamic, ?help:String) {
		if (commands.exists(str)) return;
		commands.set(str, func);
		if (help != null) commandHelp.set(str, help);
		dict.addToDictionary(str+" ");
	}
	public function removeCommand(str:String):Void {
		commands.remove(str);
		commandHelp.remove(str);
	}
	
	inline function runCommand(cmd:Dynamic, tokens:Array<Token>):Dynamic {
		var args:Array<Dynamic> = [];
		for (i in 0...tokens.length) {
			args[i] = tokens[i].getParameters()[0];
		}
		return Reflect.callMethod(null, cmd, args);
	}
	
	function execute(input:String):String {
		input = StringTools.trim(input);
		history.push(input);
		if (history.length > 10) history.shift();
		var tokens = getTokens(input);
		var cmd = tokens.shift();
		if (commands.exists(cmd.getParameters()[0])) {
			return runCommand(commands.get(cmd.getParameters()[0]), tokens);
		}
		throw "Unknown command";
	}
	
	function showHelp() 
	{
		trace("Commands are typed in the format 'command arg2 arg2':", null);
		trace("Commands:", null);
		for (c in commands.keys()) {
			trace("\t" + c + ":", null);
			if (commandHelp.exists(c)) {
				trace("\t - " + commandHelp[c], null);	
			}
		}
	}
	
	function onMouseWheel(e:MouseEvent):Void 
	{
		scroll(e.delta);
	}
	public function trace(d:Dynamic, ?pos:PosInfos) {
		var level:LogLevel = NORMAL;
		var split = (d + "").split("\n");
		if (split.length > 1) {
			for (i in split) {
				trace(i, pos);
			}
			return;
		}
		if (pos != null) {
			var shortname = pos.className.split(".").pop();
			if(pos.customParams!=null && pos.customParams.length > 0 && Std.is(pos.customParams[0], LogLevel)) {
				level = pos.customParams[0];
			}
			if (level == SYSTEM) {
				lines.push(new Line(lines.length + ": " + d, level));
			}else {
				lines.push(new Line(lines.length + ": " + shortname + ": " + d, level));
			}
		}else {
			lines.push(new Line(lines.length + ": " + d, level));
		}
		redraw();
	}
	
	inline function getMaxScroll():Int 
	{
		return cast Math.max(0, lines.length - numLinesVisible());
		//return lines.length;
	}
	public function save(outStream:IDataOutput):Void {
		outStream.writeUTFBytes(lines.join("\n"));
	}
	public function setSize(rect:Rectangle):Void 
	{
		dims = rect;
		inField.y = Math.floor(dims.height - 20);
		
		outField.width = inField.width = dims.width;
		outField.height = dims.height - 20;
		redraw();
	}
	
	public function scroll(delta:Int):Void {
		scrollPos -= delta;
		scrollPos = cast Math.min(Math.max(scrollPos, 0), getMaxScroll());
		_atBottom = scrollPos == getMaxScroll();
		redraw();
	}
	
	public function clear() 
	{
		
		lines = [new Line("Init complete at " + Date.now().toString(), SYSTEM)];
		redraw();
	}
	
	function redraw() 
	{
		if (_atBottom) {
			scrollPos = getMaxScroll();
		}
		//scrollPos = getMaxScroll();
		outField.text = "";
		var numLines = numLinesVisible();
		var scrollRange:Int = cast Math.min(lines.length, scrollPos + numLines);
		if (numLines > scrollRange - scrollPos) {
			scrollPos = getMaxScroll();
			scrollRange = cast Math.min(lines.length, scrollPos + numLines);
		}
		for (i in scrollPos...scrollRange) {
			var prevIndex:Int = outField.text.length;
			outField.appendText(lines[i].str + "\n");
			var newIndex = outField.text.length;
			switch(lines[i].level) {
				case SYSTEM:
					outField.setTextFormat(systemFmt, prevIndex, newIndex);
				case ERROR:
					outField.setTextFormat(errorFmt, prevIndex, newIndex);
				case WARNING:
					outField.setTextFormat(warnFmt, prevIndex, newIndex);
				default:
					outField.setTextFormat(normalFmt, prevIndex, newIndex);
			}
		}
	}
	
	inline function numLinesVisible():Int 
	{
		return cast Math.max(1, Math.floor((outField.height - 4) / 15));
	}
	
}