package furusystems.console;
import hscript.Expr;
/**
 * ...
 * @author Andreas Rønning
 */
enum Token {
	NULL;
	LIST(data:Array<Dynamic>);
	FLOAT(data:Float);
	INT(data:Int);
	STRING(data:String);
	UNKNOWN(data:Dynamic);
	SCRIPT(expr:Expr);
	BOOL(data:Bool);
}