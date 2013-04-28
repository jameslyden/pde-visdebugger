/* Communications.pde: serial communications functions for VisDebugger
 * Copyright 2013, James Lyden <james@lyden.org>
 * This code is licensed under the terms of the GNU General Public License.
 * See COPYING, or refer to http://www.gnu.org/licenses, for further details.
 *
 * Communications include all high- and low-level functions required to handle
 * serial communications, from the blocking read of a single byte to the
 * identification and parsing of an entire packet.
 */

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
	int CRCcalc = 0;
	int CRCsent = -1;

	// Condition buffer prior to getting new packet
	manageBuffer();

	do {
		// wait for a valid packet to be found
		while (!identifyPacket());

		// get size and timing data
		blockRead(); // flush debugDataSize, not needed here
		currReadTime = millis();

		// save channel values into data store
		for (int channel = 0; channel < channels; channel++) {
			value[channel][currSample] = blockRead();
			CRCcalc = CRCcalc + value[channel][currSample];
		}

		// Build 8-bit CRC from payload
		CRCsent = blockRead();
		CRCcalc = CRCcalc % 256;

	} while (CRCcalc != CRCsent);

	// Manage currSample pointer to maintain ring buffer
	if (++currSample >= maxSamples) {
		currSample = 0;
	}

	// update interval data
	readInterval = currReadTime - lastReadTime;
	lastReadTime = currReadTime;

}

/* boolean identifyPacket() -- helper to locate packet headers in data stream
 *
 * << complete description >>
 */
boolean identifyPacket()
{
	int data;

	// wait for first header byte
	do {
		data = blockRead();
	} while (data != 255);

	// check for valid header sequence one byte at a time
	if (blockRead() == 254) {
		if (blockRead() == 253) {
			return true;
		}
	}
	return false;
}

/* int blockRead() -- helper to read the next byte of serial data
 *
 * << complete description >>
 */
int blockRead()
{
	int serialData = -1;

	// Read continuously until it is no longer -1
	do {
		serialData = port.read();
	} while (serialData == -1);
	
	return serialData;
}

/* void manageBuffer() -- helper to clear stale buffer and maintain metrics
 *
 * If VisDebugger doesn't read bytes off the serial line fast enough, the buffer
 * can very quickly fall many seconds behind, and will continue falling behind
 * as long as the Arduino is sending data. To ensure VisDebugger is displaying
 * real-time values, the buffer is cleared before each new packet is read. The
 * global bufferWaiting variable captures the number of backlogged packets that
 * are discarded prior to each read (for use by the display).
 */
void manageBuffer()
{
	bufferWaiting = port.available();
	port.clear();
}

