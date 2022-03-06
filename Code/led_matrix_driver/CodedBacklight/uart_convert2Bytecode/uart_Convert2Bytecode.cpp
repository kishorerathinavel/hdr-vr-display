#include <iostream>
#include <fstream>
#include <cstdio>
#include <cstdlib>
#include <ATLImage.h>

using namespace std;
#define WIDTH  32
#define NPLANES 4
typedef unsigned char BYTE;

void main()
{
	HANDLE hComm;                          // Handle to the Serial port
	char   ComPortName[] = "\\\\.\\COM4"; // Name of the Serial port(May Change) to be opened,
	BOOL   Status;

	//! COM port stuff
	{
		printf("\n\n +==========================================+");
		printf("\n |  Serial Transmission (Win32 API)         |");
		printf("\n +==========================================+\n");

		//! Opening the Serial Port
		{
			wchar_t wchar_ComPortName[64];
			mbstowcs(wchar_ComPortName, ComPortName, strlen(ComPortName) + 1);
			hComm = CreateFile(wchar_ComPortName,                       // Name of the Port to be Opened
				GENERIC_READ | GENERIC_WRITE,      // Read/Write Access
				0,                                 // No Sharing, ports cant be shared
				NULL,                              // No Security
				OPEN_EXISTING,                     // Open existing port only
				0,                                 // Non Overlapped I/O
				NULL);                             // Null for Comm Devices

			if (hComm == INVALID_HANDLE_VALUE)
				printf("\n   Error! - Port %s can't be opened", ComPortName);
			else
				printf("\n   Port %s Opened\n ", ComPortName);
		}

		//! Setting the Parameters for the SerialPort
		{
			DCB dcbSerialParams = { 0 };                        // Initializing DCB structure
			dcbSerialParams.DCBlength = sizeof(dcbSerialParams);

			Status = GetCommState(hComm, &dcbSerialParams);     //retreives  the current settings

			if (Status == FALSE)
				printf("\n   Error! in GetCommState()");

			dcbSerialParams.BaudRate = 921600;      // Setting BaudRate = 115200
			dcbSerialParams.ByteSize = 8;             // Setting ByteSize = 8
			dcbSerialParams.StopBits = ONESTOPBIT;    // Setting StopBits = 1
			dcbSerialParams.Parity = NOPARITY;      // Setting Parity = None 

			Status = SetCommState(hComm, &dcbSerialParams);  //Configuring the port according to settings in DCB 

			if (Status == FALSE)
			{
				printf("\n   Error! in Setting DCB Structure");
			}
			else
			{
				printf("\n   Setting DCB Structure Successfull\n");
				printf("\n       Baudrate = %d", dcbSerialParams.BaudRate);
				printf("\n       ByteSize = %d", dcbSerialParams.ByteSize);
				printf("\n       StopBits = %d", dcbSerialParams.StopBits);
				printf("\n       Parity   = %d", dcbSerialParams.Parity);
			}
		}

		//! Setting Timeouts
		{

			COMMTIMEOUTS timeouts = { 0 };

			timeouts.ReadIntervalTimeout = 50;
			timeouts.ReadTotalTimeoutConstant = 50;
			timeouts.ReadTotalTimeoutMultiplier = 10;
			timeouts.WriteTotalTimeoutConstant = 50;
			timeouts.WriteTotalTimeoutMultiplier = 10;

			if (SetCommTimeouts(hComm, &timeouts) == FALSE)
				printf("\n   Error! in Setting Time Outs");
			else
				printf("\n\n   Setting Serial Port Timeouts Successfull \n\n");
		}
	}

	char fname[1024];  //frame0 image file
	char header[1024];  //output header file name
	wchar_t filename[4096] = { 0 };
	int w, h;
	CImage img;

	//! Input images
	{
		strcpy(fname, "../../../Simulations/HDR2004/implementation/hdr2004.png"); //frame0 image file
		MultiByteToWideChar(0, 0, fname, strlen(fname), filename, strlen(fname));
		img.Load(filename);
		w = img.GetWidth();
		h = img.GetHeight();
	}

	char *data;
	data = (char*)malloc(0.5 * 3 * w*h*sizeof(char));
	int count = 0;

	//! Convert image to bytecode
	{
		SYSTEMTIME t1, t2, t3;
		BYTE prevG, prevB;

		GetSystemTime(&t1);
		count = 0;
		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; count++) { //! Note that we're not incrementing x here. Instead we'll increment x in the loop when needed.
				//First frame image
				COLORREF color = img.GetPixel(x, y);
				BYTE r = (BYTE(color) >> 4);
				BYTE g = (BYTE(color >> 8) >> 4);
				BYTE b = (BYTE(color >> 16) >> 4);
				//BYTE r = 0; // (BYTE(color) >> 4);
				//BYTE g = 0; // (BYTE(color >> 8) >> 4);
				//BYTE b = 0; //(BYTE(color >> 16) >> 4);
				//r = (r == 0) ? 1 : r;
				//g = (g == 0) ? 1 : g;
				//b = (b == 0) ? 1 : b;

				int packingMode = count % 3;
				switch (packingMode) {
				case 0: {
					data[count] = (r << 4) | g;
					prevB = b;
					x++;
					break;
				}
				case 1: { //! The case where we skip incrementing x 
					data[count] = (prevB << 4) | r;
					prevG = g;
					prevB = b;
					break;
				}
				case 2: {
					data[count] = (prevG << 4) | prevB;
					x++;
					break;
				}
				default: {
					cout << "Undefined switch state at " << __LINE__ << endl;
				}
				}
			}
		}

		GetSystemTime(&t2);
		DWORD  dNoOfBytesWritten;          // No of bytes written to the port

		int offset = 0;
		do {

			dNoOfBytesWritten = 0;          // No of bytes written to the port
			Status = WriteFile(hComm,               // Handle to the Serialport
				&data[offset],            // Data to be written to the port 
				(count - offset),   // No of bytes to write into the port
				&dNoOfBytesWritten,  // No of bytes written to the port
				NULL);

			if (Status == FALSE)
				printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

			dNoOfBytesWritten = 0;          // No of bytes written to the port
			Status = WriteFile(hComm,               // Handle to the Serialport
				data,            // Data to be written to the port 
				offset,   // No of bytes to write into the port
				&dNoOfBytesWritten,  // No of bytes written to the port
				NULL);

			if (Status == FALSE)
				printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

			offset += 48;
			if (offset >= 1536)
				offset = 0;
		} while (0);
	}

	int refCount = (32 * 32 * 3 * 4) / 8;
	cout << "Count should be: " << refCount << endl;
	cout << "Count is: " << count << endl;
	char *bk_data = data;

	//! Writing a Character to Serial Port
	//int mode = 0;
	//switch (mode) {
	//case 0: { //! Writing many words simultaneously
	//	char   *lpBuffer;		       // lpBuffer should be  char or byte array, otherwise write wil fail
	//	lpBuffer = (char*)malloc(count*sizeof(char));
	//	for (int i = 0; i < count; i++) {
	//		//int bits[8] = { 0,0,0,0,0,0,0,0 };
	//		//bits[count % 8] = 1;
	//		//lpBuffer[i] = (bits[7] << 7)
	//		//	| (bits[6] << 6)
	//		//	| (bits[5] << 5)
	//		//	| (bits[4] << 4)
	//		//	| (bits[3] << 3)
	//		//	| (bits[2] << 2)
	//		//	| (bits[1] << 1)
	//		//	| (bits[0] << 0)
	//		//	;
	//		lpBuffer[i] = '0';
	//	}

	//	DWORD  dNoOfBytesWritten = 0;          // No of bytes written to the port

	//	Status = WriteFile(hComm,               // Handle to the Serialport
	//		lpBuffer,            // Data to be written to the port 
	//		count,
	//		&dNoOfBytesWritten,  // No of bytes written to the port
	//		NULL);

	//	if (Status == FALSE)
	//		printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

	//	break;
	//}
	//case 1: {//! Debug case
	//	int bits[8] = { 0,0,0,0,1,0,0,0 };
	//	char	temp = (bits[7] << 7)
	//		| (bits[6] << 6)
	//		| (bits[5] << 5)
	//		| (bits[4] << 4)
	//		| (bits[3] << 3)
	//		| (bits[2] << 2)
	//		| (bits[1] << 1)
	//		| (bits[0] << 0)
	//		;
	//	char lpBuffer[] = { temp };		       // lpBuffer should be  char or byte array, otherwise write wil fail
	//	DWORD  dNoOfBytesWritten = 0;          // No of bytes written to the port

	//	for (int i = 0; i < count - 2; i++) {
	//		Status = WriteFile(hComm,               // Handle to the Serialport
	//			lpBuffer,            // Data to be written to the port 
	//			1,
	//			&dNoOfBytesWritten,  // No of bytes written to the port
	//			NULL);

	//		if (Status == FALSE)
	//			printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

	//		//Sleep(50);
	//	}
	//	break;
	//}
	//case 2: {//! Send data once
	//	DWORD  dNoOfBytesWritten = 0;          // No of bytes written to the port
	//	Status = WriteFile(hComm,               // Handle to the Serialport
	//		data,            // Data to be written to the port 
	//		count,   // No of bytes to write into the port
	//		&dNoOfBytesWritten,  // No of bytes written to the port
	//		NULL);


	//	if (Status == FALSE)
	//		printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

	//	break;
	//}
	//case 3: {//! Send data byte by byte
	//	char tosend[1];

	//	DWORD  dNoOfBytesWritten = 0;          // No of bytes written to the port
	//	for (int i = 1; i < count; i++) {
	//		tosend[0] = data[i];

	//		Status = WriteFile(hComm,               // Handle to the Serialport
	//			tosend,            // Data to be written to the port 
	//			1,   // No of bytes to write into the port
	//			&dNoOfBytesWritten,  // No of bytes written to the port
	//			NULL);

	//		if (Status == FALSE)
	//			printf("\n\n   Error %d in Writing to Serial Port", GetLastError());
	//		Sleep(10);
	//	}
	//	break;
	//}
	//default: { cout << "Undefined switch state at " << __LINE__ << endl;
	//}
	//}

	CloseHandle(hComm);//Closing the Serial Port
	printf("\n ==========================================\n");
	free(bk_data);
}
