/* Display.pde: GUI functions for VisDebugger
 * James Lyden <james@lyden.org>
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

	// create basic channel grid
	for (int channel = 0; channel < channels; channel++) {
		// print channel name
		textAlign(CENTER, CENTER);
		text(chanName[channel], lGutterWidth / 2, (channel * chanHeight) + headerHeight + (chanHeight / 2));
		// alternate row colors
		if(channel % 2 == 0) {
		rectMode(CORNER);
		strokeWeight(0);
		fill(24);
		rect(lGutterWidth, (channel * chanHeight) + headerHeight + 2, canvasWidth, chanHeight);
		}
	}

	// then draw frame
	stroke(0);
	strokeWeight(2);
	line(0, headerHeight, width, headerHeight);
	line(0, height - footerHeight, width, height - footerHeight);
	line(lGutterWidth, headerHeight, lGutterWidth, height - footerHeight);
	line(width - rGutterWidth, headerHeight, width - rGutterWidth, height - footerHeight);
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
			int sample = (maxSamples + currSample - sampleNum) % maxSamples;
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
	// zoom indicator
	textAlign(CENTER, BOTTOM);
	text("zoom", width - (rGutterWidth / 2), height - footerHeight - 36);
	text("x " + zoom, width - (rGutterWidth / 2), height - footerHeight - 16);
	// TODO: add scale bar to the footer area
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
	rect(width - 6, 6, (12 - width) * bufferWaiting / 1000, headerHeight * 0.75);
	String buffered = new String(bufferWaiting / 10 + "% used");
	textAlign(CENTER, TOP);
	fill(224);
	text("buffer", width - (rGutterWidth / 2), headerHeight + 16);
	text(buffered, width - (rGutterWidth / 2), headerHeight + 36);
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

