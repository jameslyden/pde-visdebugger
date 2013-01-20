/* Utilities.pde: Generic utility functions used by VisDebugger
 * James Lyden <james@lyden.org>
 *
 * The utilities contained herein are not specific to VisDebugger and should be
 * reusable anywhere.
 */

/* void printDebug(int, String) -- print debug message if minimum level met
 * 
 * printDebug(int level, String msg) prints msg to the console if the global
 * debugLevel is set to at least level.
 */
void printDebug(int level, String msg)
{
	if (debugLevel >= level) {
		String timestamp=new String(hour() + ":" + minute() + ":" + second());
		String label=new String(timestamp + "+++D" + level + ": ");
		for (int indent = 0; indent < level; indent++) {
			label=new String(label + "   ");
		}
		println(label + msg);
	}
}

