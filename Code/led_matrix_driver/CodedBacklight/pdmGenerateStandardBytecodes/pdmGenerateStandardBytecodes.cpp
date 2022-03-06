#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <ATLImage.h>

using namespace std;
#define WIDTH  32
#define NPLANES 15
typedef unsigned char BYTE;


void UnitTest();

//"rgb" represent the upper half of the image, and "RGB" is lower half, pack 2 RGB(4bits)
// pixels in 3 bytes. Note 1 is the lowest(least significant) bit.
// ___________pB[0]_________    __________pB[1]__________    _________pB[2]___________
// |B1|G1|R1|b1|g1|r1|B0|G0|    |B2|G2|R2|b2|g2|r2|R0|b0|    |B3|G3|R3|b3|g3|r3|g0|r0|
// ----------------------- --    -------------------------    -------------------------
void PackBytes(BYTE *pB, BYTE r, BYTE g, BYTE b, BYTE R, BYTE G, BYTE B) {
	//first clear out all bits
	memset(pB, 0, sizeof(BYTE) * NPLANES);

	//set bit planes into the scrambled fashion
	for (int p = 0; p < NPLANES; p++) {

		//now get the target bit, shift to location, and then set.
		pB[p] |= (((r - p) > 0) << 2);
		pB[p] |= (((g - p) > 0) << 3);
		pB[p] |= (((b - p) > 0) << 4);
		pB[p] |= (((R - p) > 0) << 5);
		pB[p] |= (((G - p) > 0) << 6);
		pB[p] |= (((B - p) > 0) << 7);
	}
}

void main(int argc, char** argv)
{
	int w = 32;
	int h = 32;
	BYTE* bytecode1 = new BYTE[w*h / 2 * NPLANES];
	BYTE* bytecode2 = new BYTE[w*h / 2 * NPLANES];
	memset(bytecode1, 0, sizeof(BYTE)*w*h / 2 * NPLANES);
	memset(bytecode2, 0, sizeof(BYTE)*w*h / 2 * NPLANES);
	char header[1024];  //output header file name
	BYTE monoValue; // can only be between 0 and 15

	for (BYTE pixelValue = 0; pixelValue < 15; pixelValue++) {
		int location;
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
				BYTE data[NPLANES];
				BYTE r = singleLEDvalue;
				BYTE g = singleLEDvalue;
				BYTE b = singleLEDvalue;
				BYTE R = 0;
				BYTE G = 0;
				BYTE B = 0;

				PackBytes(data, r, g, b, R, G, B);
				for (int i = 0; i < NPLANES; i++) {
					bytecode1[y*WIDTH*(NPLANES)+x + WIDTH * i] = data[i];
				}

				for (int i = 0; i < NPLANES; i++) {
					bytecode2[y*WIDTH*(NPLANES)+x + WIDTH * i] = data[i];
				}
			}
		}

		sprintf(header, "pdm_single_LED%02d.h", monoValue);
		FILE* fp = fopen(header, "w");
		fprintf(fp, "#include <avr/pgmspace.h>\n");
		fprintf(fp, "static const uint8_t PROGMEM img1[] = {\n");
		for (int y = 0; y < h / 2; y++) {
			for (int i = 0; i < NPLANES; i++) {
				for (int x = 0; x < w; x++) {
					fprintf(fp, "0x%02X, ", bytecode1[y*WIDTH*(NPLANES)+x + WIDTH * i]);
				}
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
		for (int y = 0; y < h / 2; y++) {
			for (int i = 0; i < NPLANES; i++) {
				for (int x = 0; x < w; x++) {
					fprintf(fp, "0x%02X, ", bytecode2[y*WIDTH*(NPLANES)+x + WIDTH * i]);
				}
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
	}
}
