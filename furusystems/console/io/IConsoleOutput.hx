package furusystems.console.io ;
import furusystems.console.Console.Line;

/**
 * @author Andreas Rønning
 */

interface IConsoleOutput 
{
	function writeLine(line:Line):Void;
}