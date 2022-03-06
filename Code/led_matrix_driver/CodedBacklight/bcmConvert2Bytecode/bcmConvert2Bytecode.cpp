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
	for(int p = 0; p < NPLANES; p++)
	{
		if(p == 0)	//0th bit, scrambled
		{
			//now get the lowest bit, shift to location, and then set.
			pB[2] |= (r & 1)<<0;
			pB[2] |= (g & 1)<<1;
			pB[1] |= (b & 1)<<0;
			pB[1] |= (R & 1)<<1;
			pB[0] |= (G & 1)<<0;
			pB[0] |= (B & 1)<<1;
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
	char filename1[1024];  //frame0 image file
	char filename2[1024];  //frame1 image file
	char header[1024];  //output header file name

	if (argc < 4) {
		cout << "Assuming default values for images..." << endl;
		strcpy(filename1, "../../../Simulations/HDR2004/implementation/hdr2004.png"); //frame0 image file
		strcpy(filename2, "../../../Simulations/HDR2004/implementation/hdr2004.png"); //frame1 image file
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
	BYTE* bytecode1 = new BYTE[w*h / 2 * 3];
	BYTE* bytecode2 = new BYTE[w*h / 2 * 3];
	memset(bytecode1, 0, sizeof(BYTE)*w*h / 2 * 3);
	memset(bytecode2, 0, sizeof(BYTE)*w*h / 2 * 3);

	for (int y = 0; y < h / 2; y++)
	{
		for (int x = 0; x < w; x++)
		{
			//First frame image
				BYTE data[3];
			COLORREF color = img1.GetPixel(x, y);
			BYTE r = (BYTE(color) >> 4);
			BYTE g = (BYTE(color >> 8) >> 4);
			BYTE b = (BYTE(color >> 16) >> 4);
			COLORREF COLOR = img1.GetPixel(x, y + h / 2);
			BYTE R = (BYTE(COLOR) >> 4);
			BYTE G = (BYTE(COLOR >> 8) >> 4);
			BYTE B = (BYTE(COLOR >> 16) >> 4);

			PackBytes(data, r, g, b, R, G, B);
			//cout<<"Red/Green/Blue = "<<Red<<
			bytecode1[y*WIDTH*(NPLANES - 1) + x + WIDTH * 0] = data[0];
			bytecode1[y*WIDTH*(NPLANES - 1) + x + WIDTH * 1] = data[1];
			bytecode1[y*WIDTH*(NPLANES - 1) + x + WIDTH * 2] = data[2];

			//Second frame image
			color = img2.GetPixel(x, y);
			r = (BYTE(color) >> 4);
			g = (BYTE(color >> 8) >> 4);
			b = (BYTE(color >> 16) >> 4);
			COLOR = img2.GetPixel(x, y + h / 2);
			R = (BYTE(COLOR) >> 4);
			G = (BYTE(COLOR >> 8) >> 4);
			B = (BYTE(COLOR >> 16) >> 4);

			PackBytes(data, r, g, b, R, G, B);
			//cout<<"Red/Green/Blue = "<<Red<<
			bytecode2[y*WIDTH*(NPLANES - 1) + x + WIDTH * 0] = data[0];
			bytecode2[y*WIDTH*(NPLANES - 1) + x + WIDTH * 1] = data[1];
			bytecode2[y*WIDTH*(NPLANES - 1) + x + WIDTH * 2] = data[2];

		}
	}

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
