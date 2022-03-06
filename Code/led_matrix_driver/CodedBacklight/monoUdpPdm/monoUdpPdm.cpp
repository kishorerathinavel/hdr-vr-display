#include "stdafx.h"
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#include <stdio.h>
#include <winsock2.h>
#include <fstream>
#include <sstream>
#include <string>
#include <iostream>
#include <windows.h>
#include <ctime>
#include <cstdio>
#include <cstdlib>
#include <ATLImage.h>
#pragma comment(lib,"ws2_32.lib") //Winsock Library
#pragma warning(disable:4996)// declares _SCL_SECURE_NO_WARNINGS 


#define WIDTH  32
#define SERVER "172.17.199.12"  //ip address of udp server
#define BUFLEN 800  //Max length of buffer
#define PORT 8888   //The port on which to listen for incoming data

typedef unsigned char BYTE;

using namespace std;

//"rgb" represent the upper half of the image, and "RGB" is lower half, pack 2 RGB(4bits)
// pixels in 3 bytes. Note 1 is the lowest(least significant) bit.
// ___________pB[0]_________    __________pB[1]__________    _________pB[2]___________
// |B1|G1|R1|b1|g1|r1|B0|G0|    |B2|G2|R2|b2|g2|r2|R0|b0|    |B3|G3|R3|b3|g3|r3|g0|r0|
// ----------------------- --    -------------------------    -------------------------
BYTE PackBytes(BYTE i, BYTE I) {
	return (I << 4) | i;
}

void main(int argc, char** argv) {
	char filename1[1024];  //frame0 image file
	char filename2[1024];  //frame1 image file
	char header[1024];  //output header file name

	if (argc < 4) {
		cout << "Assuming default values for images..." << endl;
		strcpy(filename1, "../../../Code/HDR2004/implementation/hdr2004.png"); //frame0 image file
		strcpy(filename2, "../../../Code/HDR2004/implementation/hdr2004.png"); //frame1 image file
		strcpy(header, "test.h");    //output header file name
	}
	else {
		strcpy(filename1, argv[1]); //frame0 image file
		strcpy(filename2, argv[2]); //frame1 image file
		strcpy(header, argv[2]);    //output header file name
	}

	wchar_t filename[4096] = { 0 };

	CImage img1, img2;
	MultiByteToWideChar(0, 0, filename1, strlen(filename1), filename, strlen(filename1));
	img1.Load(filename);
	MultiByteToWideChar(0, 0, filename2, strlen(filename2), filename, strlen(filename2));
	img2.Load(filename);

	int w = img1.GetWidth();
	int h = img1.GetHeight();
	BYTE* bytecode1 = new BYTE[w*h / 2];
	BYTE* bytecode2 = new BYTE[w*h / 2];
	memset(bytecode1, 0, sizeof(BYTE)*w*h / 2);
	memset(bytecode2, 0, sizeof(BYTE)*w*h / 2);

	//Initialise winsock
	WSADATA wsa;
	struct sockaddr_in si_other;
	int s, slen = sizeof(si_other);
	char buf[BUFLEN];
	char message[BUFLEN];

	printf("\nInitialising Winsock...");
	if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0)
	{
		printf("Failed. Error Code : %d", WSAGetLastError());
		exit(EXIT_FAILURE);
	}
	printf("Initialised.\n");

	//create socket
	if ((s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == SOCKET_ERROR)
	{
		printf("socket() failed with error code : %d", WSAGetLastError());
		exit(EXIT_FAILURE);
	}

	//setup address structure
	memset((char *)&si_other, 0, sizeof(si_other));
	si_other.sin_family = AF_INET;
	si_other.sin_port = htons(PORT);
	si_other.sin_addr.S_un.S_addr = inet_addr(SERVER);

	string str, fileContents;

	int count = 0;
	//start communication
	int maxUDPpacketSize = BUFLEN, lastPos = 0, numUDPpackets = 1 + (sizeof(BYTE)*w*h / 2 / maxUDPpacketSize);
	auto begin = clock();

	while (1) {

		for (int y = 0; y < h / 2; y++) {
			for (int x = 0; x < w; x++) {
				//First frame image
				BYTE data;
				COLORREF color = img1.GetPixel(x, y);
				COLORREF COLOR = img1.GetPixel(x, y + h / 2);


				//BYTE i = (BYTE(color) >> 4) + rand() % 3;
				//BYTE I = (BYTE(COLOR) >> 4) + rand() % 3;

				BYTE i = (BYTE(color) >> 4);
				BYTE I = (BYTE(COLOR) >> 4);

				data = PackBytes(i, I);
				bytecode1[y*WIDTH + x] = data;
				bytecode2[y*WIDTH + x] = data;
			}
		}

		for (int i = 0; i < numUDPpackets; i++) {
			string ssStr;
			for (int j = 0; j < maxUDPpacketSize; j++) {
				if (i*maxUDPpacketSize + j > sizeof(BYTE)*w*h / 2) {
					break;
				}
				BYTE currbyte = bytecode1[i*maxUDPpacketSize + j];
				char curr = char(bytecode1[i*maxUDPpacketSize + j]);
				if ((int)curr == 0) {
					curr = 1;
				}
				ssStr += curr;
			}
			//cout << ssStr.length() << " " << ssStr.size() << endl;
			snprintf(message, BUFLEN, "%s%d\0", ssStr.c_str(), ssStr.size());
			if (sendto(s, message, strlen(message), 0, (struct sockaddr *) &si_other, slen) == SOCKET_ERROR) {
				printf("sendto() failed with error code : %d", WSAGetLastError());
				exit(EXIT_FAILURE);
			}
			Sleep(10);

			//for (int k = 0; k < WIDTH*WIDTH; k++) {
			//	cout << (int)message[k] << ",";
			//}
			//cout << endl;
		}
	}

	FILE* fp = fopen(header, "w");
	fprintf(fp, "#include <avr/pgmspace.h>\n");
	fprintf(fp, "static const uint8_t PROGMEM img1[] = {\n");
	for (int y = 0; y < h / 2; y++) {
		for (int x = 0; x < w; x++) {
			//BYTE currbyte = bytecode1[y*WIDTH*(NPLANES)+x + WIDTH * i];
			//char curr = char(bytecode1[y*WIDTH*(NPLANES)+x + WIDTH * i]);
			fprintf(fp, "0x%02X, ", bytecode1[y*WIDTH + x]);
		}
		if (y == h / 2 - 1)
		{
			fseek(fp, ftell(fp) - 2, SEEK_SET);
			fprintf(fp, " ");
		}
		fprintf(fp, "\n");
	}
	fprintf(fp, "};\n");	//one \b for the \n and the other for ,
	fclose(fp);




	auto end = clock();
	cout << count << endl;
	cout << "time elapsed: " << double(difftime(end, begin)) << endl;

	closesocket(s);
	WSACleanup();

}
