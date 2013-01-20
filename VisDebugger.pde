/* VisDebugger: Visualization tool for Arduino Debugger
 * James Lyden <james@lyden.org>
 *
 * VisDebugger serves as a basic (read slow/feature-free) oscilloscope/logic
 * analyzer for Arduino projects. It connects to an Arduino board and reads data
 * from the Debugger function (which sends a single set of samples per call, so
 * call it from within the main loop for best results). VisDebugger is able to
 * parse the mixed analog/digital values and automatically determine the number
 * and type of channels. It then plots the incoming data, which can be zoomed in
 * and out on, until the user closes the program.
 *
 * Setup: ensure same version and baud rate as the Arduino Debugger instance
 * NOTE: there is no provision for pushing non-debug data back on the serial
 * line, which makes it unlikely this will work alongside a second program using
 * the same serial line (even though Arduino Debugger is explicitly designed to
 * do so).
 */

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

	// Maintain buffer prior to getting new packet
	manageBuffer();

	// Use initial data set to configure channels
	do {
		// wait for at least 6 bytes (minimum packet size) to arrive
		while (!identifyPacket());

		// initialize variables dependent on channel count
		debugDataSize = blockRead();
		channels = debugDataSize - 4 - 1;
		chanHeight = (canvasHeight / channels);
		paddedChanHeight = chanHeight - (chanPadding * 2);
		initValue = new int[channels];
		chanName = new String[channels];
		chanDigital = new boolean[channels];

		// get initial interval timing data
		lastReadTime = millis();

		// read channel values into initValue and determine A/D status and names
		for (int i = 0; i < channels; i++) {
			initValue[i] = blockRead();
			// treat as digital if value is 250 or 251
			if ((initValue[i] == 250) || (initValue[i] == 251)) {
				chanName[i] = new String("DIG-" + dChannelCount++);
				chanDigital[i] = true;
			}
			else {
				chanName[i] = new String("ANA-" + aChannelCount++);
				chanDigital[i] = false;
			}
		}

		// Build 8-bit CRC from payload
		CRCsent = blockRead();
		for (int i = 0; i < channels; i++) {
			CRCcalc = CRCcalc + initValue[i];
		}
		CRCcalc = CRCcalc % 256;

	} while (CRCcalc != CRCsent);

	// Initialize data store for all samples
	value = new int[channels][maxSamples];
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
	int zoomCap = maxSamples / canvasWidth;

	switch (key) {
		case 'a':
			if (zoom < zoomCap)
				zoom *= 2.0f;
			break;
		case 'z':
			if ((1 / zoom) < zoomCap)
				zoom /= 2.0f;
			break;
	}
}

