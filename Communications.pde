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



