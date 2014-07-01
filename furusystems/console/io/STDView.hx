package furusystems.console.io ;
import furusystems.console.Console.Line;

/**
 * ...
 * @author Andreas Rønning
 */
class STDView implements IConsoleInput implements IConsoleOutput
{

	public function new() 
	{
		
	}
	
	/* INTERFACE IConsoleOutput */
	
	public function writeLine(line:Line):Void 
	{
		var timeStamp = DateTools.format(Date.fromTime(line.time), "%H:%M:%S");
		Sys.stdout().writeString(line.level + " - " + timeStamp + " // " + line.str + "\n");
	}
	
	/* INTERFACE IConsoleInput */
	
	public function readLine():String 
	{
		return Sys.stdin().readLine();
	}
	
}