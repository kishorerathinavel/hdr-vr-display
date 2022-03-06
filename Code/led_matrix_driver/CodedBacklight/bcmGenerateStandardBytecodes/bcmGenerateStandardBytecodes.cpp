#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <ATLImage.h>

using namespace std;
#define WIDTH  32
#define NPLANES 4
typedef unsigned char BYTE;


void UnitTest();

//"rgb" represent the upper half of the image, and "RGB" is lower half, pack 2 RGB(4bits)
// pixels in 3 bytes. Note 1 is the lowest(least significant) bit.
// ___________pB[0]_________    __________pB[1]__________    _________pB[2]___________
// |B1|G1|R1|b1|g1|r1|B0|G0|    |B2|G2|R2|b2|g2|r2|R0|b0|    |B3|G3|R3|b3|g3|r3|g0|r0|
// ----------------------- --    -------------------------    -------------------------
void PackBytes(BYTE *pB, BYTE r, BYTE g, BYTE b, BYTE R, BYTE G, BYTE B)
{
	//first clear out all bits
	memset(pB, 0, sizeof(BYTE) * 3);

	//set bit planes into the scrambled fashion
	for (int p = 0; p < NPLANES; p++)
	{
		if (p == 0)	//0th bit, scrambled
		{
			//now get the lowest bit, shift to location, and then set.
			pB[2] |= (r & 1) << 0;
			pB[2] |= (g & 1) << 1;
			pB[1] |= (b & 1) << 0;
			pB[1] |= (R & 1) << 1;
			pB[0] |= (G & 1) << 0;
			pB[0] |= (B & 1) << 1;
		}
		else		//other 3 bits are in the corresponding 
		{
			//now get the target bit, shift to location, and then set.
			pB[p - 1] |= (((r >> p) & 1) << 2);
			pB[p - 1] |= (((g >> p) & 1) << 3);
			pB[p - 1] |= (((b >> p) & 1) << 4);
			pB[p - 1] |= (((R >> p) & 1) << 5);
			pB[p - 1] |= (((G >> p) & 1) << 6);
			pB[p - 1] |= (((B >> p) & 1) << 7);
		}
	}
}

void main(int argc, char** argv)
{
	int w = 32;
	int h = 32;
	BYTE* bytecode1 = new BYTE[w*h / 2 * 3];
	BYTE* bytecode2 = new BYTE[w*h / 2 * 3];
	memset(bytecode1, 0, sizeof(BYTE)*w*h / 2 * 3);
	memset(bytecode2, 0, sizeof(BYTE)*w*h / 2 * 3);
	char header[1024];  //output header file name
	BYTE monoValue; // can only be between 0 and 15

	for (BYTE pixelValue = 0; pixelValue < 16; pixelValue++) {
		monoValue = pixelValue;
		for (int y = 0; y < h / 2; y++) {
			for (int x = 0; x < w; x++) {
				BYTE singleLEDvalue;
				if (y == (h / 2 - 1) && x == w / 2) {
					singleLEDvalue = monoValue;
					cout << "This works" << endl;
				}
				else {
					singleLEDvalue = 0;
				}
				//First frame image
				BYTE data[3];
				BYTE r = singleLEDvalue;
				BYTE g = singleLEDvalue;
				BYTE b = singleLEDvalue;
				BYTE R = 0; // monoValue;
				BYTE G = 0; //monoValue;
				BYTE B = 0; //monoValue;

				PackBytes(data, r, g, b, R, G, B);
				for (int i = 0; i < 3; i++) {
					bytecode1[y*WIDTH*(NPLANES - 1) + x + WIDTH * i] = data[i];
				}

				for (int i = 0; i < 3; i++) {
					bytecode2[y*WIDTH*(NPLANES - 1) + x + WIDTH * i] = data[i];
				}
			}
		}

		sprintf(header, "bcm_single_LED%02d.h", monoValue);
		FILE* fp = fopen(header, "w");
		fprintf(fp, "#include <avr/pgmspace.h>\n");
		fprintf(fp, "static const uint8_t PROGMEM img1[] = {\n");
		for (int y = 0; y < h / 2; y++)
		{
			for (int i = 0; i < w * 3; i++)
			{
				fprintf(fp, "0x%02X, ", bytecode1[y*WIDTH*(NPLANES - 1) + i]);
			}
			if (y == h / 2 - 1)
			{
				fseek(fp, ftell(fp) - 2, SEEK_SET);
				fprintf(fp, " ");
			}
			fprintf(fp, "\n");
		}
		fprintf(fp, "};\n");	//one \b for the \n and the other for ,

		fprintf(fp, "static const uint8_t PROGMEM img2[] = {\n");
		for (int y = 0; y < h / 2; y++)
		{
			for (int i = 0; i < w * 3; i++)
			{
				fprintf(fp, "0x%02X, ", bytecode2[y*WIDTH*(NPLANES - 1) + i]);
			}
			if (y == h / 2 - 1)
			{
				fseek(fp, ftell(fp) - 2, SEEK_SET);
				fprintf(fp, " ");
			}
			fprintf(fp, "\n");
		}
		fprintf(fp, "};\n");
		fclose(fp);
	}
}
