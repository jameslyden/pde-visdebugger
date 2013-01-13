/* VisDebugger: Visualization tool for Arduino Debugger
 * James Lyden <james@lyden.org>
 *
 * Setup: ensure same version and baud rate as the Arduino Debugger instance
 * NOTE: there is no provision for pushing non-debug data back on the serial
 * line, which makes it unlikely this will work alongside a second program using
 * the same serial line (even though Arduino Debugger is explicitly designed to
 * do so).
 */

//##############################################################################
// GLOBAL DEFINITIONS: moved to GlobalVars.pde
//##############################################################################

//##############################################################################
// MANDATORY FUNCTIONS
//##############################################################################

/* void setup() -- mandatory initialization function
 *
 * setup() constructs the UI, syncs to the serial stream, and configures the
 * channel count/types. At completion, control is handed to draw() for
 * continuous data/UI updates.
 */
void setup()
{
	// construct window and enable 2xAA
	size(windowWidth, windowHeight);
	smooth(2);

	// init local variables
	int debugDataSize = 0;
	int CRCcalc = 0;
	int CRCsent = -1;
	int[] initValue;
	int dChannelCount = 0;
	int aChannelCount = 0;

	// Use initial data set to configure channels
	printDebug(1, "Initializing program.");
	port.clear();
	do {
		// wait for at least 6 bytes (minimum packet size) to arrive
		printDebug(2, "Waiting for packet...");
		while (!identifyPacket());

		// initialize variables dependent on channel count
		debugDataSize = blockRead(port);
		channels = debugDataSize - 4 - 1;
		printDebug(2, channels + " channels detected.");
		chanHeight = (canvasHeight / channels);
		paddedChanHeight = chanHeight - (chanPadding * 2);
		initValue = new int[channels];
		chanName = new String[channels];
		chanDigital = new boolean[channels];

		// get initial interval timing data
		lastReadTime = millis();

		// read channel values into initValue and determine A/D status and names
		for (int i = 0; i < channels; i++) {
			initValue[i] = blockRead(port);
			// treat as digital if value is 250 or 251
			if ((initValue[i] == 250) || (initValue[i] == 251)) {
				chanName[i] = new String("DIG-" + dChannelCount++);
				chanDigital[i] = true;
			}
			else {
				chanName[i] = new String("ANA-" + aChannelCount++);
				chanDigital[i] = false;
			}
			printDebug(3, "Added " + chanName[i] + " (value " + initValue[i] + ").");
		}

		// Build 8-bit CRC from payload
		printDebug(2, "Calculating CRC...");
		CRCsent = blockRead(port);
		for (int i = 0; i < channels; i++) {
			CRCcalc = CRCcalc + initValue[i];
		}
		CRCcalc = CRCcalc % 256;

		if (CRCcalc != CRCsent)
			printDebug(3, "CRC mismatch, " + CRCcalc + "/" + CRCsent + ". Starting over.");
	} while (CRCcalc != CRCsent);
	printDebug(3, "CRC matches.");
	printDebug(2, "Packet read. Initializing data store..."); 

	// Initialize data store for all samples
	value = new int[channels][maxSamples];
	printDebug(1, "Initialization complete.");
}

/* void draw() -- mandatory loop function
 *
 * draw() initiates a data update followed by a UI update. The UI update is a
 * complete refresh of all UI elements at every pass (including header/footer
 * and other relatively static data). Note that operator inputs are handled
 * by interrupt, which triggers the built-in keyReleased() function.
 */
void draw()
{
		readNewData();
		redrawScreen();
}


//##############################################################################
// COMMUNICATIONS FUNCTIONS: moved to Communications.pde
//##############################################################################

/* void readNewData() -- get new samples from serial port (blocking call)
 *
 * readNewData() performs header ID, parsing, and CRC validation. If the new
 * data is acceptable, the data store and current sample pointer are updated.
 * readNewData() will not return to the calling function until a valid packet
 * is received.
 */
void readNewData()
{
	// init local variables
	int debugDataSize = 0;
	int CRCcalc = 0;  
	int CRCsent = -1;
	int[] tempValue = new int[channels];

	// Use initial data set to configure channels
	printDebug(3, "Getting new serial data.");
	do {
		// wait for at least 6 bytes (minimum packet size) to arrive
		printDebug(4, "Waiting for packet...");
		while (!identifyPacket());

		// get size and timing data
		debugDataSize = blockRead(port);
		currReadTime = millis();

		// save channel values into tempValue until CRC is validated
		for (int i = 0; i < channels; i++) {
			tempValue[i] = blockRead(port);
			CRCcalc = CRCcalc + tempValue[i];
			printDebug(5, "Received " + tempValue[i] + " for " + chanName[i] + ".");
		}

		// Build 8-bit CRC from payload
		printDebug(5, "Evalulating CRC...");
		CRCsent = blockRead(port);
		CRCcalc = CRCcalc % 256;

		if (CRCcalc != CRCsent)
			printDebug(4, "CRC mismatch, " + CRCcalc + "/" + CRCsent + ". Starting over.");
	} while (CRCcalc != CRCsent);
	printDebug(5, "CRC matches.");
	printDebug(3, "Packet read. Adding to data store..."); 

	// Manage currSample pointer to maintain ring buffer
	if (++currSample >= maxSamples) {
		currSample = 0;
		printDebug(3, "Ring buffer index rolled over.");
	}
	// Transfer contents of tempValue to next slot in data store
	for (int i = 0; i < channels; i++) {
		value[i][currSample] = tempValue[i];
		printDebug(5, "Inserted " + value[i][currSample] + " into value[" + i + "][" + currSample + "].");
	}

	// update interval data
	readInterval = currReadTime - lastReadTime;
	lastReadTime = currReadTime;

	// if the buffer is too full, purge it in order to stay timely
	bufferWaiting = port.available();
	if (bufferWaiting > 1000) {
		printDebug(2, "Buffer full. Purging.");
		port.clear();
	}
	printDebug(3, "Finished getting serial data.");
}

/* boolean identifyPacket() -- helper to read until valid packet header is found
 *
 * << complete description >>
 */
boolean identifyPacket()
{
	int data;

	// wait for first header byte, then enough bytes for a complete packet
	do {
		data = blockRead(port);
		printDebug(6, "read byte: " + data);
	} while (data != 255);

	// check for valid header sequence one byte at a time
	printDebug(4, "Inspecting packet...");
	port.buffer(1);
	if (blockRead(port) == 254) {
		port.buffer(1);
		if (blockRead(port) == 253) {
			printDebug(5, "Header correct. Continuing...");
			return true;
		}
	}
	return false;
}

/* int blockRead(Serial) -- helper to read the next byte of serial data
 *
 * << complete description >>
 */
int blockRead(Serial openPort)
{
	printDebug(6, "blockRead called.");
	int serialData = -1;

	// wait until port indicates data is present
//	while (openPort.available() == 0);

	// and then read until it is no longer -1
	do {
		serialData = openPort.read();
	} while (serialData == -1);
	
	printDebug(6, "blockRead returning " + serialData + ".");
	return serialData;
}


//##############################################################################
// DISPLAY FUNCTIONS
//##############################################################################

/* void redrawScreen() -- update the UI with new sample data
 *
 * << complete the description >>
 */
void redrawScreen()
{
	// create basic channel grid first
	background(32);
	for (int i = 0; i < channels; i++) {
		if(i % 2 == 0) {
		rectMode(CORNER);
		strokeWeight(0);
		fill(24);
		rect(lGutterWidth, (i * chanHeight) + headerHeight + 2, canvasWidth, chanHeight);
		}
	}

	// then draw frame
	stroke(0);
	strokeWeight(2);
	line(0, headerHeight, width, headerHeight);
	line(0, height - footerHeight, width, height - footerHeight);
	line(lGutterWidth, headerHeight, lGutterWidth, height - footerHeight);
	line(width - rGutterWidth, headerHeight, width - rGutterWidth, height - footerHeight);

	// restore to "defaults"
	stroke(0);
	strokeWeight(1);
	fill(255);

	// plot the data
	stroke(255);
	int firstDataCol = width - rGutterWidth - 2;
	for (int channel = 0; channel < channels; channel++) {
		// print channel name
		textAlign(CENTER, CENTER);
		text(chanName[channel], lGutterWidth / 2, (channel * chanHeight) + headerHeight + (chanHeight / 2));
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
		// plot points
		int channelBase = ((channel + 1) * chanHeight) + headerHeight + 2;
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
				int lastSample = (sample + 1) % maxSamples;
				if ((value[channel][lastSample] + value[channel][sample]) == (250 + 251)) {
					line(x, channelBase - scaleVertical(250), x, channelBase - scaleVertical(251));
				}
			}
		}
	}		

	// zoom indicator
	textAlign(CENTER, BOTTOM);
	text("zoom", width - (rGutterWidth / 2), height - footerHeight - 36);
	text("x " + zoom, width - (rGutterWidth / 2), height - footerHeight - 16);
	// TODO: add scale bar to the footer area

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

	printDebug(6, "scaleVertical called for " + unscaledHeight);
	if (unscaledHeight == 250) {
		scaledHeight = chanPadding;
		printDebug(6, "scaleVertical returning " + scaledHeight + " for LOW.");
	}
	else if (unscaledHeight == 251) {
		scaledHeight = chanHeight - chanPadding;
		printDebug(6, "scaleVertical returning " + scaledHeight + " for HIGH.");
	}
	else {
		float scaleFactor = paddedChanHeight/250.0f;
		scaledHeight = (int)(unscaledHeight * scaleFactor) + chanPadding;
		printDebug(6, "scaleVertical returning " + scaledHeight + " for analog.");
	}

	return scaledHeight;
}


//##############################################################################
// INTERRUPT SERVICE ROUTINES
//##############################################################################

/* void keyReleased() -- built-in keyboard interrupt service routine
 *
 * keyReleased() is triggered on every key release event. It is used for all
 * UI control, currently consisting of zoom in/zoom out capabilities. This is
 * likely to expand to pause/play and seeking forward/back in the near future.
 */
void keyReleased() 
{
	printDebug(1, "Entering keypress handler.");
	switch (key) {
		case '+':
			zoom *= 2.0f;
			if ((maxSamples / canvasWidth) < zoom)
				zoom /= 2.0f;
			printDebug(2, "Zoom in. Zoom level: " + zoom + ".");		
			break;
		case '-':
			zoom /= 2.0f;
			if ((5 * maxSamples / canvasWidth) < (1 / zoom))
				zoom *= 2.0f;
			printDebug(2, "Zoom out. Zoom level: " + zoom + ".");		
			break;
	}
	printDebug(1, "Leaving keypress handler.");
}


//##############################################################################
// GENERIC HELPER FUNCTIONS: moved to Utilities.pde
//##############################################################################

//##############################################################################
// Cogito ergo FIN ~~ I think, therefore I END
//##############################################################################
