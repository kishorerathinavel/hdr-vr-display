 // 
#include <math.h>
#include <ctime>
using namespace std;
#include <ATLImage.h>

// OpenGL Graphics includes
#include <GL/glew.h>
#include <GL/freeglut.h>

// CUDA utilities and system includes
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>

#include <helper_cuda.h>       // CUDA device initialization helper functions
#include <helper_cuda_gl.h>    // CUDA device + OpenGL initialization functions

// Shared Library Test Functions
#include <helper_functions.h>  // CUDA SDK Helper functions

#define MAX_EPSILON_ERROR   5.0f
#define REFRESH_DELAY       10 //ms
#define MIN_RUNTIME_VERSION 1000
#define MIN_COMPUTE_VERSION 0x10

//---UART-------------------------------------------------------------------------------
HANDLE hComm;                          // Handle to the Serial port
char   ComPortName[] = "\\\\.\\COM4"; // Name of the Serial port(May Change) to be opened,
BOOL   Status;
int redColumn = 0, redRow = 0;

typedef unsigned char BYTE;
void openComPort();
void setParametersComPort();
void setTimingsComPort();


//---Window variables--------------------------------------------------------------------
const static char *sSDKsample = "HDR VR HMD";
unsigned int width, height;
//unsigned int  *hImage  = NULL;
float* pImage = NULL;
float* pSubSample = NULL;

//---Textures and FBOs----------------------------------------------------------------
GLuint pbo;     // OpenGL pixel buffer object
struct cudaGraphicsResource *cuda_pbo_resource; // handles OpenGL-CUDA exchange
GLuint texid;   // texture
GLuint shader;

//---Stopwatch-----------------------------------------------------------------------
StopWatchInterface *timer = NULL;
StopWatchInterface *kernel_timer = NULL;


//---fps-----------------------------------------------------------------------------
int fpsCount = 0;        // FPS count for averaging
int fpsLimit = 1;        // FPS limit for sampling
unsigned int g_TotalErrors = 0;
bool         g_bInteractive = false;
unsigned int ITER = 1;

//#define GL_TEXTURE_TYPE GL_TEXTURE_RECTANGLE_ARB
#define GL_TEXTURE_TYPE GL_TEXTURE_2D


// These are CUDA functions to handle allocation and launching the kernels
extern "C" void		initTexture(int width, int height, int ratio, void *pImage, void *pSubImage);
extern "C" void		freeTextures();
extern "C" void		InitializeSolverMemory(int width, int height, int ratio);
extern "C" double	HdrVrHmdSolver(int* LAB_PHASE, int* STEP, float *d_dest, int width, int height, int K, StopWatchInterface *timer, int display_val, float lambda);

extern "C"	void GetModulationLayer(float4* target, int width, int height);
extern "C"	void GetPrimaryLayer(float4* target, int width, int height, int ratio);
extern "C"	void GetSimulatedBLLayer(float4* target, int width, int height);
extern "C"	void GetRecLayer(float4* target, int width, int height);



bool	checkCUDAProfile(int dev, int min_runtime, int min_compute);
int		findCapableDevice(int argc, char **argv);
void	keyboard(unsigned char key, int /*x*/, int /*y*/);
void	specialFunc(int key, int x, int y);
void	reshape(int x, int y);
void	computeFPS(double KernelTime);
void	timerEvent(int value);
void	loadImageData(char* filename);

void	saveImageData(char* filename, int width, int height, float* data);
void	saveImageData(char* filename, int width, int height, float4* data);
void	cleanup();


//---Factorization parameters--------------------------------------------------------
int		displayVal = 0;
float	ADMM_RHO = 0;
int		LAB_PHASE = 0;
int		STEP = 1;
bool	capture_data = true;//false;
int		LED_RATIO = 15;
float	LAMBDA = 0.02;

void SaveFactorizationImage()
{
	float4 *P = NULL, *BL = NULL;
	float4* M = NULL, *Rec = NULL;

	M = new float4[width*height];				memset(M, 0, sizeof(float4)*width*height);
	Rec = new float4[width*height];				memset(Rec, 0, sizeof(float4)*width*height);
	P = new float4[(width / LED_RATIO)*(height / LED_RATIO)];	memset(P, 0, sizeof(float4)*(width / LED_RATIO)*(height / LED_RATIO));
	char filename[200];
	GetModulationLayer(M, width, height);				sprintf(filename, "outputs/%d_Modulation.png", ITER);			saveImageData(filename, width, height, M);
	GetPrimaryLayer(P, width, height, LED_RATIO);		sprintf(filename, "outputs/%d_Primary.png", ITER);				saveImageData(filename, width / LED_RATIO, height / LED_RATIO, P);
	GetRecLayer(Rec, width, height);				sprintf(filename, "outputs/%d_Reconstruction.png", ITER);		saveImageData(filename, width, height, Rec);
	GetRecLayer(Rec, width, height);		sprintf(filename, "outputs/%d_Reconstruction_.png", ITER);			saveImageData(filename, width, height, Rec);

	delete[] P;
	delete[] Rec;
	delete[] M;
	//capture_data = false;
}

// display results using OpenGL
void display()
{
	//std::cout<<"STEP == "<<STEP<<endl;
	cudaEvent_t start, stop;
	float time;
	cudaEventCreate(&start);
	cudaEventCreate(&stop);
	//clock_t t = clock();
	cudaEventRecord(start, 0);
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// execute filter, writing results to pbo
	float *dResult;
	//DEPRECATED: checkCudaErrors( cudaGLMapBufferObject((void**)&d_result, pbo) );
	checkCudaErrors(cudaGraphicsMapResources(1, &cuda_pbo_resource, 0));
	size_t num_bytes;
	checkCudaErrors(cudaGraphicsResourceGetMappedPointer((void **)&dResult, &num_bytes, cuda_pbo_resource));
	double KernelTime = HdrVrHmdSolver(&LAB_PHASE, &STEP, dResult, width, height, LED_RATIO, kernel_timer, displayVal, LAMBDA);
	//t = clock() - t;
	//printf("Duration = %f ms\n", double(t)/(double)CLOCKS_PER_SEC * 1000.f);
	//std::cout<<"duration = ( t ) / (double) CLOCKS_PER_SEC;<<std::endl;
	// DEPRECATED: checkCudaErrors(cudaGLUnmapBufferObject(pbo));
	checkCudaErrors(cudaGraphicsUnmapResources(1, &cuda_pbo_resource, 0));
	if (LAB_PHASE && ITER < 10)
	{
		if (capture_data)
			SaveFactorizationImage();
		ITER++;
		//cleanup();
		//exit(0);
	}



	////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Common display code path
	{
		glClear(GL_COLOR_BUFFER_BIT);

		// load texture from pbo
		glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, pbo);
		glBindTexture(GL_TEXTURE_2D, texid);
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RGBA, GL_FLOAT, 0);
		glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, 0);

		// fragment program is required to display floating point texture
		glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, shader);
		glEnable(GL_FRAGMENT_PROGRAM_ARB);
		glDisable(GL_DEPTH_TEST);

		glBegin(GL_QUADS);
		{
			glTexCoord2f(0, 0);            glVertex2f(0, 0);
			glTexCoord2f(1, 0);            glVertex2f(1, 0);
			glTexCoord2f(1, 1);            glVertex2f(1, 1);
			glTexCoord2f(0, 1);            glVertex2f(0, 1);
		}
		glEnd();
		glBindTexture(GL_TEXTURE_TYPE, 0);
		glDisable(GL_FRAGMENT_PROGRAM_ARB);
	}

	////! Write UART Code here
	//{
	//	float *P = NULL;
	//	int pWidth = width / LED_RATIO;
	//	int pHeight = height / LED_RATIO;
	//	if (pWidth < 32 || pHeight < 32) {
	//		cout << "FPGA UART receiver assumes that the image being transmitted is 32 x 32. Write code to pad image" << endl;
	//		exit(0);
	//	}

	//	// From this point onwards, we'll assume that the image is 32 x 32. If the image is bigger, we'll take only the 32 x 32 subimage
	//	P = new float4[pWidth*pHeight];	memset(P, 0, sizeof(float4)*pWidth*pHeight);
	//	GetPrimaryLayer(P, width, height, LED_RATIO);
	//	int count = 0;
	//	char *data;
	//	data = (char*)malloc(0.5 * 3 * 32 * 32 * sizeof(char));
	//	BYTE prevG, prevB;
	//	bool rgb_backlight = false;
	//	//redColumn++;
	//	//if (redColumn == 32) {
	//	//	redRow++;
	//	//	if (redRow == 32)
	//	//		redRow = 0;
	//	//	redColumn = 0;
	//	//}
	//	for (int y = 0; y < 32; y++) {
	//		for (int x = 0; x < 32; count++) { //! Note that we're not incrementing x here. Instead we'll increment x in the loop when needed.
	//			COLORREF color = (int)(255 * P[y * pWidth + x]);
	//			BYTE r, g, b;
	//			if (rgb_backlight) {
	//				r = (BYTE(color) >> 4);
	//				g = (BYTE(color >> 8) >> 4);
	//				b = (BYTE(color >> 16) >> 4);
	//			}
	//			else {
	//				r = (BYTE(color) >> 4);
	//				g = (BYTE(color) >> 4);
	//				b = (BYTE(color) >> 4);
	//			}

	//			if (y == x) {
	//				r = 15;
	//				g = 0;
	//				b = 0;
	//			}

	//			//if (y == redColumn && x == redRow) {
	//			//	r = 1;
	//			//	g = 0;
	//			//	b = 0;
	//			//}

	//			//BYTE r = 0; // (BYTE(color) >> 4);
	//			//BYTE g = 0; // (BYTE(color >> 8) >> 4);
	//			//BYTE b = 0; //(BYTE(color >> 16) >> 4);
	//			//r = (r == 0) ? 1 : r;
	//			//g = (g == 0) ? 1 : g;
	//			//b = (b == 0) ? 1 : b;

	//			int packingMode = count % 3;
	//			switch (packingMode) {
	//			case 0: {
	//				data[count] = (r << 4) | g;
	//				prevB = b;
	//				x++;
	//				break;
	//			}
	//			case 1: { //! The case where we skip incrementing x 
	//				data[count] = (prevB << 4) | r;
	//				prevG = g;
	//				prevB = b;
	//				break;
	//			}
	//			case 2: {
	//				data[count] = (prevG << 4) | prevB;
	//				x++;
	//				break;
	//			}
	//			default: {
	//				cout << "Undefined switch state at " << __LINE__ << endl;
	//			}
	//			}
	//		}
	//	}

	//	DWORD  dNoOfBytesWritten;          // No of bytes written to the port
	//	bool sendUARTonce = false;
	//	if (sendUARTonce) {
	//		dNoOfBytesWritten = 0;          // No of bytes written to the port
	//		Status = WriteFile(hComm,               // Handle to the Serialport
	//			data,            // Data to be written to the port 
	//			count,   // No of bytes to write into the port
	//			&dNoOfBytesWritten,  // No of bytes written to the port
	//			NULL);

	//		if (Status == FALSE)
	//			printf("\n\n   Error %d in Writing to Serial Port", GetLastError());
	//	}
	//	else {
	//		int offset = 0;
	//		while (1) {

	//			dNoOfBytesWritten = 0;          // No of bytes written to the port
	//			Status = WriteFile(hComm,               // Handle to the Serialport
	//				&data[offset],            // Data to be written to the port 
	//				(count - offset),   // No of bytes to write into the port
	//				&dNoOfBytesWritten,  // No of bytes written to the port
	//				NULL);

	//			if (Status == FALSE)
	//				printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

	//			dNoOfBytesWritten = 0;          // No of bytes written to the port
	//			Status = WriteFile(hComm,               // Handle to the Serialport
	//				data,            // Data to be written to the port 
	//				offset,   // No of bytes to write into the port
	//				&dNoOfBytesWritten,  // No of bytes written to the port
	//				NULL);

	//			if (Status == FALSE)
	//				printf("\n\n   Error %d in Writing to Serial Port", GetLastError());

	//			offset += 48;
	//			if (offset >= 1536)
	//				offset = 0;
	//		}
	//	}

	//	delete[] P;
	//	delete[] data;
	//}

	glutSwapBuffers();
	//glutReportErrors();

	//sdkStopTimer(&timer);
	cudaEventRecord(stop, 0);
	cudaEventSynchronize(stop);
	cudaEventElapsedTime(&time, start, stop);
	//cout<<time<<endl;
	computeFPS(time);
}

void initCuda()
{
	//initialize gaussian mask
	//updateGaussian(gaussian_delta, filter_radius);

	initTexture(width, height, 20, pImage, pSubSample);
	sdkCreateTimer(&timer);
	sdkCreateTimer(&kernel_timer);
}

void cleanup()
{
	sdkDeleteTimer(&timer);
	sdkDeleteTimer(&kernel_timer);

	if (pImage)
	{
		delete[] pImage;
	}

	freeTextures();

	//DEPRECATED: checkCudaErrors(cudaGLUnregisterBufferObject(pbo));
	cudaGraphicsUnregisterResource(cuda_pbo_resource);

	glDeleteBuffersARB(1, &pbo);
	glDeleteTextures(1, &texid);
	glDeleteProgramsARB(1, &shader);

	// cudaDeviceReset causes the driver to clean up all state. While
	// not mandatory in normal operation, it is good practice.  It is also
	// needed to ensure correct operation when the application is being
	// profiled. Calling cudaDeviceReset causes all profile data to be
	// flushed before the application exits
	cudaDeviceReset();
}

// shader for displaying floating-point texture
static const char *shader_code =
"!!ARBfp1.0\n"
"TEX result.color, fragment.texcoord, texture[0], 2D; \n"
"END";

GLuint compileASMShader(GLenum program_type, const char *code)
{
	GLuint program_id;
	glGenProgramsARB(1, &program_id);
	glBindProgramARB(program_type, program_id);
	glProgramStringARB(program_type, GL_PROGRAM_FORMAT_ASCII_ARB, (GLsizei)strlen(code), (GLubyte *)code);

	GLint error_pos;
	glGetIntegerv(GL_PROGRAM_ERROR_POSITION_ARB, &error_pos);

	if (error_pos != -1)
	{
		const GLubyte *error_string;
		error_string = glGetString(GL_PROGRAM_ERROR_STRING_ARB);
		printf("Program error at position: %d\n%s\n", (int)error_pos, error_string);
		return 0;
	}

	return program_id;
}

void initGLResources()
{
	// create pixel buffer object
	glGenBuffersARB(1, &pbo);
	glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, pbo);
	glBufferDataARB(GL_PIXEL_UNPACK_BUFFER_ARB, width*height * 4 * sizeof(float), 0, GL_STREAM_DRAW_ARB);

	glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, 0);
	// DEPRECATED: checkCudaErrors(cudaGLRegisterBufferObject(pbo));
	checkCudaErrors(cudaGraphicsGLRegisterBuffer(&cuda_pbo_resource, pbo, cudaGraphicsMapFlagsWriteDiscard));

	// create texture for display
	glGenTextures(1, &texid);
	glBindTexture(GL_TEXTURE_2D, texid);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glBindTexture(GL_TEXTURE_2D, 0);

	// load shader program
	shader = compileASMShader(GL_FRAGMENT_PROGRAM_ARB, shader_code);
}


void initGL(int argc, char **argv)
{
	// initialize GLUT
	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE);
	glutInitWindowSize(width, height);

	glutInitWindowPosition(100, 100);
	glutCreateWindow("CUDA HDR VR HMD");

	glutDisplayFunc(display);

	glutKeyboardFunc(keyboard);
	glutReshapeFunc(reshape);
	glutSpecialFunc(specialFunc);
	//glutIdleFunc(idle);
	glutTimerFunc(REFRESH_DELAY, timerEvent, 0);

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






////////////////////////////////////////////////////////////////////////////////
// Program main
////////////////////////////////////////////////////////////////////////////////
int main(int argc, char **argv)
{
	// start logs
	int devID;
	char *ref_file = NULL;

	printf("Usage = HDR_VR_HMD.exe targetimage.png save_result(0 or 1) Beta Lambda");
	if (argc < 3)
	{
		printf("Give a file name\n");
	}
	if (argc >= 3)
		capture_data = atoi(argv[2]);
	if (argc >= 4)
		LAMBDA = atof(argv[3]);


	cout << "Lambda = " << LAMBDA << endl;
	loadImageData(argv[1]);
	{
		initGL(argc, (char **)argv);
		int dev = findCapableDevice(argc, argv);

		if (dev != -1)
		{
			dev = gpuGLDeviceInit(argc, (const char **)argv);
			if (dev == -1)	exit(EXIT_FAILURE);
		}
		else
		{
			cudaDeviceReset();	// Causes the driver to clean up all state, a good practice.
			exit(EXIT_SUCCESS);
		}

		// Now we can create a CUDA context and bind it to the OpenGL context
		initCuda();
		initGLResources();
		glutCloseFunc(cleanup);

		openComPort();
		setParametersComPort();
		setTimingsComPort();

		glutMainLoop();// Main OpenGL loop that will run visualization for every vsync
	}
}

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


/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Some CUDA device checking routine
bool checkCUDAProfile(int dev, int min_runtime, int min_compute)
{
	int runtimeVersion = 0;

	cudaDeviceProp deviceProp;
	cudaGetDeviceProperties(&deviceProp, dev);

	fprintf(stderr, "\nDevice %d: \"%s\"\n", dev, deviceProp.name);
	cudaRuntimeGetVersion(&runtimeVersion);
	fprintf(stderr, "  CUDA Runtime Version     :\t%d.%d\n", runtimeVersion / 1000, (runtimeVersion % 100) / 10);
	fprintf(stderr, "  CUDA Compute Capability  :\t%d.%d\n", deviceProp.major, deviceProp.minor);

	if (runtimeVersion >= min_runtime && ((deviceProp.major << 4) + deviceProp.minor) >= min_compute)
		return true;
	else
		return false;
}

int findCapableDevice(int argc, char **argv)
{
	int dev;
	int bestDev = -1;

	int deviceCount = 0;
	cudaError_t error_id = cudaGetDeviceCount(&deviceCount);

	if (error_id != cudaSuccess)
	{
		fprintf(stderr, "cudaGetDeviceCount returned %d\n-> %s\n", (int)error_id, cudaGetErrorString(error_id));
		exit(EXIT_FAILURE);
	}

	if (deviceCount == 0)
	{
		fprintf(stderr, "There are no CUDA capabile devices.\n");
	}
	else
	{
		fprintf(stderr, "Found %d CUDA Capable device(s) supporting CUDA\n", deviceCount);
	}

	for (dev = 0; dev < deviceCount; ++dev)
	{
		cudaDeviceProp deviceProp;
		cudaGetDeviceProperties(&deviceProp, dev);

		if (checkCUDAProfile(dev, MIN_RUNTIME_VERSION, MIN_COMPUTE_VERSION))
		{
			fprintf(stderr, "\nFound CUDA Capable Device %d: \"%s\"\n", dev, deviceProp.name);

			if (bestDev == -1)
			{
				bestDev = dev;
				fprintf(stderr, "Setting active device to %d\n", bestDev);
			}
		}
	}

	if (bestDev == -1)
	{
		fprintf(stderr, "\nNo configuration with available capabilities was found.  Test has been waived.\n");
		fprintf(stderr, "The CUDA Sample minimum requirements:\n");
		fprintf(stderr, "\tCUDA Compute Capability >= %d.%d is required\n", MIN_COMPUTE_VERSION / 16, MIN_COMPUTE_VERSION % 16);
		fprintf(stderr, "\tCUDA Runtime Version    >= %d.%d is required\n", MIN_RUNTIME_VERSION / 1000, (MIN_RUNTIME_VERSION % 100) / 10);
		exit(EXIT_WAIVED);
	}

	return bestDev;
}

void specialFunc(int key, int x, int y) {
}



/////////////////////////////////////////////////////////////////////////////////////////////////////////
// OpenGL events
void keyboard(unsigned char key, int /*x*/, int /*y*/)
{
	switch (key)
	{
	case 27:
		cleanup();
		exit(0);
		break;
	case 'r':	//spacebar
		InitializeSolverMemory(width, height, LED_RATIO);
		break;

	case '[':
		displayVal--;
		if (displayVal < 0) displayVal = 0;
		switch (displayVal)
		{
		case 0:		printf("Reconstructed Image\n");	break;
		case 1:		printf("Target Image\n");	break;
		case 2:		printf("Modulation Frame \n");	break;
		case 3:		printf("Primaries Frame\n");	break;
		}
		break;

	case ']':
		displayVal++;
		if (displayVal > 3) displayVal = 3;
		switch (displayVal)
		{
		case 0:		printf("Reconstructed Image\n");	break;
		case 1:		printf("Target Image\n");	break;
		case 2:		printf("Modulation Frame \n");	break;
		case 3:		printf("Primaries Frame\n");	break;
		}
		break;

	default:
		break;
	}
	glutPostRedisplay();
}


void reshape(int x, int y)
{
	glViewport(0, 0, x, y);

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
		//float ifps = 1.0f / (sdkGetAverageTimerValue(&timer) / 1000.0f);

		switch (displayVal)
		{
		case 0:		sprintf(fps, "Reconstructed Image @ %3.f fps", ifps);	break;
		case 1:		sprintf(fps, "Target Image @ %3.f fps", ifps);	break;
		case 2:		sprintf(fps, "Modulation Frame @ %3.f fps", ifps);	break;
		case 3:		sprintf(fps, "Primaries Frame @ %3.f fps", ifps);	break;
		case 4:		sprintf(fps, "Target Image in XYZ @ %3.f fps", ifps);	break;
		case 5:		sprintf(fps, "RECxyz Image in XYZ @ %3.f fps", ifps);	break;
		}
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

void loadImageData(char* filename)
{
	CImage img;

	if (img.Load(filename) != S_OK)
	{
		printf("Cannot load image\n");
		exit(0);
	}

	width = img.GetWidth();
	height = img.GetHeight();

	pImage = new float[width*height * 4];
	memset(pImage, 0, sizeof(float)*width*height * 4);

	for (int y = 0; y < height; y++)
	{
		for (int x = 0; x < width; x++)
		{
			COLORREF color = img.GetPixel(x, y);
			BYTE R = BYTE(color);
			BYTE G = BYTE(color >> 8);
			BYTE B = BYTE(color >> 16);

			pImage[(height - y - 1)*width * 4 + x * 4 + 0] = R / 255.f;
			pImage[(height - y - 1)*width * 4 + x * 4 + 1] = G / 255.f;
			pImage[(height - y - 1)*width * 4 + x * 4 + 2] = B / 255.f;
		}
	}
}

void saveImageData(char* filename, int _width, int _height, float4* data)
{
	CImage img;

	img.Create(_width, _height, 24);

	for (int y = 0; y < _height; y++)
	{
		for (int x = 0; x < _width; x++)
		{
			float4 val = data[y*_width + x];
			unsigned char r = unsigned char(val.x * 255);
			unsigned char g = unsigned char(val.y * 255);
			unsigned char b = unsigned char(val.z * 255);
			img.SetPixelRGB(x, (_height - y - 1), r, g, b);
		}
	}

	img.Save(filename);
}

void saveImageData(char* filename, int _width, int _height, float* data)
{
	CImage img;

	img.Create(_width, _height, 24);

	for (int y = 0; y < _height; y++)
	{
		for (int x = 0; x < _width; x++)
		{
			float val = data[y*_width + x];
			unsigned char r = unsigned char(val * 255);
			unsigned char g = unsigned char(val * 255);
			unsigned char b = unsigned char(val * 255);
			img.SetPixelRGB(x, (_height - y - 1), r, g, b);
		}
	}

	img.Save(filename);
}