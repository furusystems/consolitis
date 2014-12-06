package furusystems.console;
#if (flash||openfl)
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
import furusystems.autocomplete.flash.AutocompleteManager;
#else
import furusystems.console.io.STDView;
#end
import furusystems.console.Console.Line;
import furusystems.console.io.IConsoleInput;
import furusystems.console.io.IConsoleOutput;
import haxe.io.BytesOutput;
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
	INFO;
	WARNING;
	ERROR;
}
class Line {
	public var source:String;
	public var level:LogLevel;
	public var lineNo:Int;
	public var str:String;
	public var time:Float;
	public var timeStamp:String;
	public inline function new(source:String, str:String, level:LogLevel, lineNo:Int, time:Float) {
		this.source = source;
		this.level = level;
		this.str = str;
		this.lineNo = lineNo;
		this.time = time;
		timeStamp = DateTools.format(Date.now(), "%T");
	}
}
#if (flash||openfl)
class Console extends Sprite
#else
class Console
#end
{
	#if (flash||openfl)
	public var maxLines:Int;
	var outField:TextField;
	var inField:TextField;
	var autoComplete:AutocompleteManager;
	var lines:Array<Line>;
	var scrollPos:Int = 0;
	var history:Array<String>;
	var dict:AutocompleteDictionary;
	static var normalFmt = new TextFormat("_typewriter", 12, 0xbbbbbb);
	static var systemFmt = new TextFormat("_typewriter", 12, 0x00bb00);
	static var errorFmt = new TextFormat("_typewriter", 12, 0xbb0000);
	static var warnFmt = new TextFormat("_typewriter", 12, 0xF18856);
	var _atBottom:Bool;
	var dims:Rectangle;
	#end
	var commands:Map<String,Dynamic>;
	var commandHelp:Map<String,String>;
	
	
	var lineCount:Int = 0;
	public var input:IConsoleInput;
	public var outputs:Array<IConsoleOutput>;
	public var showTimestamp:Bool;
	public var showSource:Bool;
	
	public var defaultHandler:Null<String->Dynamic>;
	public function new() 
	{
		showTimestamp = false;
		showSource = true;
		maxLines = -1;
		outputs = [];
		commands = new Map<String,Dynamic>();
		commandHelp = new Map<String,String>();
		
		#if (neko || cpp)
		outputs.push(cast input = new STDView());
		#end
		Log.trace = handleTrace;
		
		#if (flash||openfl)
		super();
		addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
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
		createCommand("clear", clear, "Clear the console");
		_atBottom = true;
		#end
		
		createCommand("help", showHelp, "Show this help");
		#if flash
			trace("Session start on " + Date.now().toString());
		#else
			trace("Session start on " + DateTools.format(Date.now(), "%A, %b %d"));
		#end
	}
	
	#if !(flash||openfl)
	public function start():Void {
		Sys.stdout().writeString("\033[2J\033[1;1H");
	}
	#end
	
	#if (flash||openfl)
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
			#if !cpp
			e.preventDefault();
			#end
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
				#if !cpp
				e.preventDefault();
				#end
				inField.text = history.pop();
				inField.setSelection(0, inField.text.length);
			}
		}
	}
	
	function onMouseWheel(e:MouseEvent):Void 
	{
		scroll(e.delta);
	}
	
	
	inline function getMaxScroll():Int 
	{
		return cast Math.max(0, lines.length - numLinesVisible());
	}
	public function save(outStream:IDataOutput):Void {
		outStream.writeUTFBytes(lines.join("\r\n"));
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
		lineCount = 0;
		lines = [new Line(null, "Init complete at " + Date.now().toString(), SYSTEM, lineCount, Date.now().getTime())];
		redraw();
	}
	
	function redraw() 
	{
		if (_atBottom) {
			scrollPos = getMaxScroll();
		}
		outField.text = "";
		var numLines = numLinesVisible();
		var scrollRange:Int = cast Math.min(lines.length, scrollPos + numLines);
		if (numLines > scrollRange - scrollPos) {
			scrollPos = getMaxScroll();
			scrollRange = cast Math.min(lines.length, scrollPos + numLines);
		}
		for (i in scrollPos...scrollRange) {
			var prevIndex:Int = outField.text.length;
			var str = lines[i].str;
			if (showSource&&lines[i].source!=null) {
				str = lines[i].source+": " + str;
			}
			if (showTimestamp) {
				str = lines[i].timeStamp + " : " + str;
			}
			outField.appendText(str + "\n");
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
	
	#end
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
		}
		return out;
	}
	
	public function createCommand(str:String, func:Dynamic, ?help:String) {
		if (commands.exists(str)) return;
		commands.set(str, func);
		if (help != null) commandHelp.set(str, help);
		#if (openfl || flash) 
		dict.addToDictionary(str + " ");
		#end
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
		#if (openfl||flash)
		history.push(input);
		if (history.length > 10) history.shift();
		#end
		var tokens = getTokens(input);
		var cmd = tokens.shift();
		if (commands.exists(cmd.getParameters()[0])) {
			return runCommand(commands.get(cmd.getParameters()[0]), tokens);
		}
		if (defaultHandler == null) throw "Unknown command";
		else return defaultHandler(input);
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
	
	function writeLine(line:Line):Void {
		#if (openfl || flash) 
			lines.push(line);
			if (maxLines > -1) {
				while (lines.length > maxLines) {
					lines.shift();
				}
			}
			redraw();
		#end
		for (o in outputs) {
			o.writeLine(line);
		}
	}
	
	public function handleTrace(d:Dynamic, ?pos:PosInfos) {
		var time = Date.now().getTime();
		var level:LogLevel = INFO;
		var split = (d + "").split("\n");
		if(split.length>1){
			while (split.length > 1){
				trace(split.shift(), pos);
			}
			return;
		}
		
		var l:Null<Line>;
		if (pos != null) {
			var shortname = pos.className.split(".").pop();
			if(pos.customParams!=null && pos.customParams.length > 0 && Std.is(pos.customParams[0], LogLevel)) {
				level = pos.customParams[0];
			}
			if (level == SYSTEM) {
				l = new Line(null, d, level, lineCount++, time);
			}else {
				l = new Line(shortname, d, level, lineCount++, time);
			}
		}else {
			l = new Line(null, d, level, lineCount++, time);
		}
		
		writeLine(l);
	}
	
}