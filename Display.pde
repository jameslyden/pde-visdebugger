/* Display.pde: GUI functions for VisDebugger
 * Copyright 2013, James Lyden <james@lyden.org>
 * This code is licensed under the terms of the GNU General Public License.
 * See COPYING, or refer to http://www.gnu.org/licenses, for further details.
 *
 * All functions related to the display of data onscreen, including backdrop,
 * scaling and color determination of components, and plotting of debug data,
 * are contained herein.
 */

/* void redrawScreen() -- update the UI with new sample data
 *
 * << complete the description >>
 */
void redrawScreen()
{
	drawBackground();
	resetDisplayDefaults();
	printValues();
	printScale();
	printBuffer();
	printSpeed();
}

/* void drawBackground() -- redraw all static display elements
 *
 * << complete the description >>
 */
void drawBackground()
{
	// lay down base color
	background(32);

	// then draw frame
	stroke(0);
	strokeWeight(2);
	line(0, headerHeight, width, headerHeight);
	line(0, height - footerHeight, width, height - footerHeight);
	line(lGutterWidth, headerHeight, lGutterWidth, height - footerHeight);
	line(width - rGutterWidth, headerHeight, width - rGutterWidth, height - footerHeight);

	// create basic channel grid
	for (int channel = 0; channel < channels; channel++) {
		// print channel name
		fill(255);
		textAlign(CENTER, CENTER);
		text(chanName[channel], lGutterWidth / 2, (channel * chanHeight) + headerHeight + (chanHeight / 2));
		clearPlot(channel);
	}
}

/* void clearPlot(int channel) -- clears plotted points/value for given channel
 *
 * << complete the description >>
 */
void clearPlot(int channel)
{
	rectMode(CORNER);
	strokeWeight(0);
	// alternate row colors
	if(channel % 2 == 0) fill(24);
	else fill(32);
	rect(lGutterWidth + 2, (channel * chanHeight) + headerHeight + 2, canvasWidth - 3, chanHeight);
}

/* void resetDisplayDefaults() -- resets shape drawing parameters to defaults
 *
 * << complete the description >>
 */
void resetDisplayDefaults()
{
	// restore to "defaults"
	stroke(0);
	strokeWeight(1);
	fill(255);
}

/* void printValues() -- prints all data associated with channels
 *
 * << complete the description >>
 */
void printValues()
{
	// plot the data
	stroke(255);
	fill(255);
	for (int channel = 0; channel < channels; channel++) {
		labelChannel(channel);
		plotPoints(channel);
	}
}

/* void labelChannel(int channel) -- prints name and current value of channel
 *
 * << complete the description >>
 */
void labelChannel(int channel)
{
	// print current value
	String printedValue;
	switch (value[channel][currSample]) {
		case 250:
			printedValue = new String("LOW");
			break;
		case 251:
			printedValue = new String("HIGH");
			break;
		default:
			float voltage = round(value[channel][currSample] * voltFactor * 100) / 100.0;
			printedValue = new String(voltage + "V");
			break;
	}
	textAlign(LEFT, CENTER);
	text(printedValue, lGutterWidth + chanPadding * 2, (channel * chanHeight) + headerHeight + (chanHeight / 2));
}

/* void plotPoints(int channel) -- plots values for channel as 2D graph
 *
 * << complete the description >>
 */
void plotPoints(int channel)
{
	// plot points
	int firstDataCol = width - rGutterWidth - 2;
	int channelBase = ((channel + 1) * chanHeight) + headerHeight + 2;
	lastValue = 0;
	for (int dataCol = 0; dataCol < canvasWidth - 2; dataCol++) {
		int sampleNum = (int)(dataCol / zoom);
		// Only draw a point if data exists
		if (sampleNum < maxSamples) {
			int sample = (maxSamples + currSample - sampleNum - 1) % maxSamples;
			int sampleValue = value[channel][sample];
			int x = firstDataCol - dataCol;
			int y = channelBase - scaleVertical(sampleValue);
			point(x, y);
			// Connect HIGH/LOW lines
			if ((lastValue + sampleValue) == 501) {
				line(x, channelBase - scaleVertical(250), x, channelBase - scaleVertical(251));
			}
			lastValue = sampleValue;
		}
	}
}

/* void printScale() -- prints zoom factor and scale bar in footer
 *
 * << complete the description >>
 */
void printScale()
{
	int spacing = 160;	// pixel distance between ticks
	int markLoc;			// x-coord of where to set the current mark
	
	// zoom indicator
	textAlign(RIGHT, CENTER);
	text("x" + zoom + " zoom", width - 6, height - footerHeight / 2);
	// draw scale bar in the footer area
	textAlign(CENTER, BOTTOM);
	for (int scaleStep = 0; scaleStep < canvasWidth; scaleStep += spacing) {
		markLoc = width - rGutterWidth - scaleStep;
		text(int(scaleStep / zoom), markLoc, height);
		// tick mark
		stroke(0);
		line(markLoc, height - footerHeight - 5, markLoc, height - footerHeight + 5);
	}
	// final marker
	text(int(canvasWidth / zoom), lGutterWidth, height);
	stroke(0);
	line(lGutterWidth, height - footerHeight - 5, lGutterWidth, height - footerHeight + 5);
}

/* void printBuffer() -- prints buffer backlog value and colored indicator
 *
 * << complete the description >>
 */
void printBuffer()
{
	// buffer fill indicator
	if (bufferWaiting < 25) {
		fill(0,144,0);	
	}
	else if (bufferWaiting < 50) {
		fill(0,192,0);	
	}
	else if (bufferWaiting < 100) {
		fill(144,192,0);	
	}
	else if (bufferWaiting < 200) {
		fill(192,144,0);	
	}
	else if (bufferWaiting < 400) {
		fill(192,96,0);	
	}
	else {
		fill(192,0,0);	
	}
	rectMode(CORNER);
	rect(6, 6, 12 + bufferWaiting, headerHeight * 0.75);
	String buffered = new String("Buffer: " + bufferWaiting / 10 + "% used ");
	textAlign(RIGHT, CENTER);
	fill(224);
	text(buffered, width - 15, headerHeight / 2);
}

/* void printSpeed() -- prints data acquisition speed value and indicator
 *
 * << complete the description >>
 */
void printSpeed()
{
	// data acquisition speed indicator
	if (readInterval < 15) {
		fill(0,144,0);	
	}
	else if (readInterval < 20) {
		fill(0,192,0);	
	}
	else if (readInterval < 25) {
		fill(144,192,0);	
	}
	else if (readInterval < 35) {
		fill(192,144,0);	
	}
	else if (readInterval < 50) {
		fill(192,96,0);	
	}
	else {
		fill(192,0,0);	
	}
	rectMode(CENTER);
	rect(width - (rGutterWidth / 2), headerHeight + (canvasHeight / 2), rGutterWidth - 16, 32);
	String timing = new String(readInterval + " ms");
	textAlign(CENTER, TOP);
	fill(224);
	text("speed", width - (rGutterWidth / 2), headerHeight + (canvasHeight / 2) - 32);
	textAlign(CENTER, BOTTOM);
	text(timing, width - (rGutterWidth / 2), headerHeight + (canvasHeight / 2) + 32);
}

/* int scaleVertical(int) -- helper to map channel value to allotted area
 *
 * scaleVertical(int uH) takes integer analog or digital sensor value uH, as
 * provided by the Debugger program, and maps it to a sensible scale that will
 * fit within the space allotted to a single channel. For digital values, this
 * means HIGH maps close to the upper bound of the space, while LOW maps close
 * to the lower bound. For analog values, it is a direct linear scaling effect.
 */
int scaleVertical(int unscaledHeight)
{
	int scaledHeight;

	if (unscaledHeight == 250) {
		scaledHeight = chanPadding;
	}
	else if (unscaledHeight == 251) {
		scaledHeight = chanHeight - chanPadding;
	}
	else {
		float scaleFactor = paddedChanHeight/250.0f;
		scaledHeight = (int)(unscaledHeight * scaleFactor) + chanPadding;
	}

	return scaledHeight;
}

