#include <iostream>
#include <fstream>
#include <cstdio>
#include <cstdlib>
#include <ATLImage.h>

using namespace std;
#define WIDTH  32
#define NPLANES 4
typedef unsigned char BYTE;


void UnitTest();

void main(int argc, char** argv)
{
	char filename1[1024];  //frame0 image file
	char filename2[1024];  //frame1 image file
	char header[1024];  //output header file name

	if (argc < 4) {
		cout << "Assuming default values for images..." << endl;
		strcpy(filename1, "../../../Simulations/HDR2004/implementation/hdr2004.png"); //frame0 image file
		strcpy(filename2, "../../../Simulations/HDR2004/implementation/hdr2004.png"); //frame1 image file
		strcpy(header, "example1.coe");    //output header file name
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
	short int bytecode1;
	short int bytecode2;

	FILE* fp1 = fopen(header, "w");
	FILE* fp2 = fopen("example2.coe", "w");
	fprintf(fp1, "memory_initialization_radix=16;\n");
	fprintf(fp1, "memory_initialization_vector=\n");
	fprintf(fp2, "memory_initialization_radix=16;\n");
	fprintf(fp2, "memory_initialization_vector=\n");


	for (int y = 0; y < h / 2; y++)
	{
		for (int x = 0; x < w; x++)
		{
			//First frame image
			COLORREF color = img1.GetPixel(x, y);
			BYTE r = (BYTE(color) >> 4);
			BYTE g = (BYTE(color >> 8) >> 4);
			BYTE b = (BYTE(color >> 16) >> 4);
			bytecode1 = 0;
			bytecode1 = (r & 15) << 8;
			bytecode1 |= g << 4;
			bytecode1 |= b;
			fprintf(fp1, "%03x,\n", bytecode1);

			COLORREF COLOR = img1.GetPixel(x, y + h / 2);
			BYTE R = (BYTE(COLOR) >> 4);
			BYTE G = (BYTE(COLOR >> 8) >> 4);
			BYTE B = (BYTE(COLOR >> 16) >> 4);
			bytecode2 = R << 8;
			bytecode2 |= G << 4;
			bytecode2 |= B;
			fprintf(fp2, "%03x,\n", bytecode2);
		}
	}
	fseek(fp1, -3, SEEK_CUR);
	fprintf(fp1, ";\n", bytecode1);
	fseek(fp2, -3, SEEK_CUR);
	fprintf(fp2, ";\n", bytecode2);	


	fclose(fp1);
	fclose(fp2);
}
