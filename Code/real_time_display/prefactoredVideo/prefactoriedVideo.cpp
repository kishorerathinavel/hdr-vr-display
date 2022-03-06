// 
#include <math.h>
#include <ctime>
using namespace std;
#include <ATLImage.h>
#include "FreeImage.h"

// OpenGL Graphics includes
#include <GL/glew.h>
#include <GL/freeglut.h>

// Shared Library Test Functions
#include <helper_functions.h>  

#define REFRESH_DELAY       10 //ms

//---UART-------------------------------------------------------------------------------
HANDLE hComm;                          // Handle to the Serial port
char   ComPortName[] = "\\\\.\\COM4"; // Name of the Serial port(May Change) to be opened,
BOOL   Status;
int redColumn = 0, redRow = 0;

typedef unsigned char BYTE;
void openComPort();
void setParametersComPort();
void setTimingsComPort();

bool sendUARTonce = false;
bool sentonce = false;
bool scroll = false;
int offset = 0;
int showReferenceBacklightImage = 1;
bool show_white = false;


//---Window variables--------------------------------------------------------------------
const static char *sSDKsample = "HDR VR HMD";
unsigned int width = 800, height = 600;

//---Textures and FBOs----------------------------------------------------------------
GLuint texid;   // texture
char* pImage = NULL;
char* rImage = NULL;
char* fImage = NULL;
float* mImage = NULL;
unsigned int pWidth, pHeight, pCount;


//---Stopwatch-----------------------------------------------------------------------
StopWatchInterface *timer = NULL;
StopWatchInterface *kernel_timer = NULL;

//---fps-----------------------------------------------------------------------------
int fpsCount = 0;        // FPS count for averaging
int fpsLimit = 1;        // FPS limit for sampling
unsigned int g_TotalErrors = 0;
bool         g_bInteractive = false;
unsigned int ITER = 1;

#define GL_TEXTURE_TYPE GL_TEXTURE_2D

void	keyboard(unsigned char key, int /*x*/, int /*y*/);
void	specialFunc(int key, int x, int y);
void	reshape(int x, int y);
void	computeFPS(double KernelTime);
void	timerEvent(int value);

float xscale = 0.1, yscale = 0.2;
float xt = 0.0, yt = 0.0;

/// <summary>
/// Draws the texture to framebuffer. 
/// Note that the following opereations need to be done before calling this function, if applicable:
/// scissor test, glClearColor, glClear, glViewport
/// </summary>
/// <param name="textureID">The texture identifier.</param>
void drawTextureToFramebuffer(int textureID) {
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, 1, 0, 1, -1, 1);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glColor3f(1, 1, 1);
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, textureID);
	glBegin(GL_QUADS);

	glTexCoord2f(1, 1); glVertex3f(0 + xscale + xt, 0 + yscale + yt, 0);
	glTexCoord2f(0, 1); glVertex3f(1 - xscale + xt, 0 + yscale + yt, 0);
	glTexCoord2f(0, 0); glVertex3f(1 - xscale + xt, 1 - yscale + yt, 0);
	glTexCoord2f(1, 0); glVertex3f(0 + xscale + xt, 1 - yscale + yt, 0);
	glEnd();
	glDisable(GL_TEXTURE_2D);
}

char* toShow;
// display results using OpenGL
void display()
{
	//TODO Implement texture scrolling

	//! Display Modulation image as texture
	{
		if (show_white)
			glClearColor(1.0, 1.0, 1.0, 1.0);
		else
			glClearColor(0.0, 0.0, 0.0, 0.0);

		glClear(GL_COLOR_BUFFER_BIT);
		glViewport(0, 0, width, height);
		//glEnable(GL_BLEND);
		//glBlendFunc(GL_SRC_COLOR, GL_DST_COLOR);
		//glBlendEquation(GL_FUNC_ADD);
		if (!show_white)
			drawTextureToFramebuffer(texid);
		//glDisable(GL_BLEND);
	}

	switch (showReferenceBacklightImage) {
	case 1: toShow = rImage; break;
	case 2: toShow = pImage; break;
	case 3: toShow = fImage; break;
	default: cout << "Undefined switch state at " << __LINE__ << endl;
	}

	//! Transmit Backlight over UART
	{
		if (pWidth < 32 || pHeight < 32) {
			cout << "FPGA UART receiver assumes that the image being transmitted is 32 x 32. Write code to pad image" << endl;
			exit(0);
		}

		//! From this point onwards, we'll assume that the image is 32 x 32. If the image is bigger, we'll take only the 32 x 32 subimage

		DWORD  dNoOfBytesWritten;          // No of bytes written to the port

		if (scroll) {
			dNoOfBytesWritten = 0;          // No of bytes written to the port
			Status = WriteFile(hComm,               // Handle to the Serialport
				&toShow[offset],            // toShow to be written to the port 
				(pCount - offset),   // No of bytes to write into the port
				&dNoOfBytesWritten,  // No of bytes written to the port
				NULL);

			if (Status == FALSE)
				printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

			dNoOfBytesWritten = 0;          // No of bytes written to the port
			Status = WriteFile(hComm,               // Handle to the Serialport
				toShow,            // toShow to be written to the port 
				offset,   // No of bytes to write into the port
				&dNoOfBytesWritten,  // No of bytes written to the port
				NULL);

			if (Status == FALSE)
				printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

			offset += (32 * 1.5);
			if (offset >= (32 * 32 * 1.5))
				offset = 0;
		}
		else if (!sentonce) {
			dNoOfBytesWritten = 0;          // No of bytes written to the port
			Status = WriteFile(hComm,               // Handle to the Serialport
				toShow,            // toShow to be written to the port 
				pCount,   // No of bytes to write into the port
				&dNoOfBytesWritten,  // No of bytes written to the port
				NULL);

			if (Status == FALSE)
				printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

			sentonce = true;
		}
	}

	glutSwapBuffers();
}

void loadTexture(const char* lpszPathName, GLuint tex) {


	FREE_IMAGE_FORMAT fif = FIF_UNKNOWN;

	fif = FreeImage_GetFileType(lpszPathName, 0);
	if (fif == FIF_UNKNOWN) {
		fif = FreeImage_GetFIFFromFilename(lpszPathName);
	}

	if ((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif)) {
		FIBITMAP *image = FreeImage_Load(fif, lpszPathName, 0);
		if (image != NULL) {
			//convert to 32-bpp so things will be properly aligned 
			FIBITMAP* temp = image;
			image = FreeImage_ConvertTo32Bits(image);
			FreeImage_Unload(temp);


			glBindTexture(GL_TEXTURE_2D, tex);
			glPixelStorei(GL_UNPACK_ROW_LENGTH, FreeImage_GetPitch(image) / 4);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, FreeImage_GetWidth(image), FreeImage_GetHeight(image), 0, GL_BGRA, GL_UNSIGNED_BYTE, FreeImage_GetBits(image));
			FreeImage_Unload(image);
		}
		else {
			printf("error reading image '%s', exiting...\n", lpszPathName);
			exit(1);
		}
	}
	else {
		printf("missing/unknown/unsupported image '%s', exiting...\n", lpszPathName);
		exit(1);
	}

}

int maxr = 0, maxg = 0, maxb = 0;
int sumr = 0, sumg = 0, sumb = 0;
int meanr, meang, meanb;
int countNonZeroBacklightPixels = 0;

void loadBacklightImage()
{
	char fname[1024] = "hdr2004.png";  //frame0 image file
	wchar_t filename[4096] = { 0 };
	CImage img;

	//! Input images
	{
		img.Load(fname);
		pWidth = img.GetWidth();
		pHeight = img.GetHeight();
	}

	pImage = (char*)malloc(0.5 * 3 * pWidth*pHeight*sizeof(char));
	pCount = 0;
	//! Convert image to bytecode
	{
		SYSTEMTIME t1, t2, t3;
		BYTE prevG, prevB;

		GetSystemTime(&t1);
		pCount = 0;
		for (int y = 0; y < pHeight; y++) {
			for (int x = 0; x < pWidth; pCount++) { //! Note that we're not incrementing x here. Instead we'll increment x in the loop when needed.
											  //First frame image
				COLORREF color = img.GetPixel(x, y);

				BYTE r = (BYTE(color) >> 4);
				BYTE g = (BYTE(color >> 8) >> 4);
				BYTE b = (BYTE(color >> 16) >> 4);

				maxr = (r > maxr) ? r : maxr;
				maxg = (g > maxg) ? g : maxg;
				maxb = (b > maxb) ? b : maxb;

				if (color > 0) {
					sumr += r;
					sumg += g;
					sumb += b;
					countNonZeroBacklightPixels++;
				}


				int packingMode = pCount % 3;
				switch (packingMode) {
				case 0: {
					pImage[pCount] = (r << 4) | g;
					prevB = b;
					x++;
					break;
				}
				case 1: { //! The case where we skip incrementing x 
					pImage[pCount] = (prevB << 4) | r;
					prevG = g;
					prevB = b;
					break;
				}
				case 2: {
					pImage[pCount] = (prevG << 4) | prevB;
					x++;
					break;
				}
				default: {
					cout << "Undefined switch state at " << __LINE__ << endl;
				}
				}
			}
		}
	}
}


void loadReferenceBacklightImage()
{
	char fname[1024] = "hdr2004.png";  //frame0 image file
	wchar_t filename[4096] = { 0 };
	CImage img;

	//! Input images
	{
		img.Load(fname);
		pWidth = img.GetWidth();
		pHeight = img.GetHeight();
	}

	rImage = (char*)malloc(0.5 * 3 * pWidth*pHeight*sizeof(char));
	fImage = (char*)malloc(0.5 * 3 * pWidth*pHeight*sizeof(char));
	pCount = 0;
	//! Convert image to bytecode
	{
		SYSTEMTIME t1, t2, t3;
		BYTE prevG, prevB;
		BYTE fprevG, fprevB;

		GetSystemTime(&t1);
		pCount = 0;
		for (int y = 0; y < pHeight; y++) {
			for (int x = 0; x < pWidth; pCount++) { //! Note that we're not incrementing x here. Instead we'll increment x in the loop when needed.
											  //First frame image
				COLORREF color = img.GetPixel(x, y);
				BYTE r, g, b;
				BYTE fr, fg, fb;
				if (x > 0 && x < 19 && y > 0 && y < 30) {
					r = meanr; g = meang; b = meanb;
					fr = 15; fg = 15; fb = 15;
				}
				else {
					r = 0; g = 0; b = 0;
					fr = 0; fg = 0; fb = 0;
				}

				int packingMode = pCount % 3;
				switch (packingMode) {
				case 0: {
					rImage[pCount] = (r << 4) | g;
					fImage[pCount] = (fr << 4) | fg;
					prevB = b;
					fprevB = fb;
					x++;
					break;
				}
				case 1: { //! The case where we skip incrementing x 
					rImage[pCount] = (prevB << 4) | r;
					fImage[pCount] = (fprevB << 4) | fr;
					prevG = g;
					prevB = b;
					fprevG = fg;
					fprevB = fb;
					break;
				}
				case 2: {
					rImage[pCount] = (prevG << 4) | prevB;
					fImage[pCount] = (fprevG << 4) | fprevB;
					x++;
					break;
				}
				default: {
					cout << "Undefined switch state at " << __LINE__ << endl;
				}
				}
			}
		}
	}
}



void initGLResources()
{
	char filename[1024];

	// create texture for display
	glGenTextures(1, &texid);
	glBindTexture(GL_TEXTURE_2D, texid);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	sprintf(filename, "modulation.png");
	loadTexture(filename, texid);
}


void initGL(int argc, char **argv)
{
	// initialize GLUT
	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE);
	glutInitWindowSize(width, height);

	glutInitWindowPosition(100, 100);
	glutCreateWindow("HDR VR HMD");

	glutDisplayFunc(display);

	glutKeyboardFunc(keyboard);
	glutReshapeFunc(reshape);
	glutSpecialFunc(specialFunc);
	//glutIdleFunc(idle);
	glutTimerFunc(REFRESH_DELAY, timerEvent, 0);

	sdkCreateTimer(&timer);
	sdkCreateTimer(&kernel_timer);

	glewInit();

	if (!glewIsSupported("GL_VERSION_1_5 GL_ARB_vertex_buffer_object GL_ARB_pixel_buffer_object"))
	{
		printf("Error: failed to get minimal extensions for demo\n");
		printf("This sample requires:\n");
		printf("  OpenGL version 1.5\n");
		printf("  GL_ARB_vertex_buffer_object\n");
		printf("  GL_ARB_pixel_buffer_object\n");
		exit(EXIT_FAILURE);
	}
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// UART Transmission
void openComPort() {
	hComm = CreateFile(ComPortName,                       // Name of the Port to be Opened
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

void setParametersComPort() {
	DCB dcbSerialParams = { 0 };                        // Initializing DCB structure
	dcbSerialParams.DCBlength = sizeof(dcbSerialParams);

	Status = GetCommState(hComm, &dcbSerialParams);     //retreives  the current settings

	if (Status == FALSE)
		printf("\n   Error! in GetCommState()");

	//dcbSerialParams.BaudRate = CBR_256000;      // Setting BaudRate = 115200
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

void setTimingsComPort() {
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


void specialFunc(int key, int x, int y) {
}

void print_roi_info() {
	cout << xscale << " " << yscale << " " << xt << " " << yt << endl;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// OpenGL events
void keyboard(unsigned char key, int /*x*/, int /*y*/)
{
	switch (key)
	{
	case 27: exit(0); break;
	case 'f': glutFullScreen(); break;
	case ' ': {
		showReferenceBacklightImage = (++showReferenceBacklightImage == 4) ? 1 : showReferenceBacklightImage;
		if (!scroll) sentonce = false;
		break;
	}
	case '1': {
		showReferenceBacklightImage = 1;
		if (!scroll) sentonce = false;
		break;
	}
	case '2': {
		showReferenceBacklightImage = 2;
		if (!scroll) sentonce = false;
		break;
	}
	case '3': {
		showReferenceBacklightImage = 3;
		if (!scroll) sentonce = false;
		break;
	}
	case 'w': show_white = !show_white; break;
	case 'i': xscale += 0.01; print_roi_info();  break;
	case 'o': xscale -= 0.01; print_roi_info(); break;
	case 'k': yscale += 0.01; print_roi_info(); break;
	case 'l': yscale -= 0.01; print_roi_info(); break;
	case 'y': xt -= 0.01; print_roi_info(); break;  
	case 'u': xt += 0.01; print_roi_info(); break; 
	case 'h': yt -= 0.01; print_roi_info(); break; 
	case 'j': yt += 0.01; print_roi_info(); break; 
	default: cout << "Undefined switch state at " << __LINE__ << endl; break;
	}
	glutPostRedisplay();
}


void reshape(int x, int y)
{
	glViewport(0, 0, x, y);
	width = x;
	height = y;

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0.0, 1.0, 0.0, 1.0, 0.0, 1.0);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Really random helper function
void computeFPS(double kernelTime)
{
	fpsCount++;

	if (fpsCount == fpsLimit)
	{
		char fps[256];
		float ifps = 1.0f / (kernelTime / 1000.0f);
		glutSetWindowTitle(fps);

		fpsCount = 0;
		fpsLimit = (int)MAX(ifps, 1.0f);
		sdkResetTimer(&timer);
	}
}

void timerEvent(int value)
{
	if (glutGetWindow())
	{
		glutPostRedisplay();
		glutTimerFunc(REFRESH_DELAY, timerEvent, 0);
	}
}

////////////////////////////////////////////////////////////////////////////////
// Program main
////////////////////////////////////////////////////////////////////////////////
void main(int argc, char **argv)
{
	initGL(argc, (char **)argv);
	initGLResources();
	loadBacklightImage();
	cout << "Max R G B :" << maxr << " " << maxg << " " << maxb << endl;
	meanr = sumr / countNonZeroBacklightPixels;
	meang = sumg / countNonZeroBacklightPixels;
	meanb = sumb / countNonZeroBacklightPixels;
	cout << "Mean R G B :" << meanr << " " << meang << " " << meanb << endl;
	loadReferenceBacklightImage();

	openComPort();
	setParametersComPort();
	setTimingsComPort();

	glutMainLoop();// Main OpenGL loop that will run visualization for every vsync
}

