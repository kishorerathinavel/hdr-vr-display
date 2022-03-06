#include <helper_math.h>
#include <helper_functions.h>
#include <helper_cuda.h>       // CUDA device initialization helper functions
#include <iostream>
using namespace std;
#define SIGMA 20	//was 20, 10 works fine
#define DENOM_C 49.f/(2.f*3.1415926f*SIGMA*SIGMA)*6.5		//consider 7x7 rectangular area of the LED light diode


// all on device memory
float4 *dM = NULL;	//Modulation layer, size is m-by-n
float4 *dP = NULL;	//Primary layer, size is (m/K)-by-(n/K) where K is the backlight ratio
float4 *dRec = NULL;	//Temporary reconstruction contributions, dimension is  m-by-n-by-3
float4 *dBL = NULL;	//Temporary storage for diffused backlight layer (immediately behind LCD)
float4 *dImageRGB  = NULL, *dImageXYZ = NULL;   //original image
float4 *dTemp = NULL;
size_t pitch;
texture<float4, 2, cudaReadModeElementType> Target;


__global__ void ShowModulation(float4 *od, float4* M, int w, int h);
__global__ void ShowBacklight(float4 *od, float4* BL, int w, int h);
__global__ void BuildRecFromSimulatedBL(float4 *Rec, float4* M, float4* BL, int w, int h);
__global__ void InitializeTargetImage(float4* Target, int ImageWidth, int ImageHeight, int K); // Image edges darkening to avoid overfitting of the primary...
__global__ void SolveForModulationWithBL(float4* Rec, float4* M, float4* BL, int w, int h, int K);
__global__ void SolveForPrimary(float4* Rec, int ImageWidth, int ImageHeight, int K, float4* M, float4* P);
__global__ void UpdatePrimary(float4* P, float4* Update, int ImageWidth, int ImageHeight, int K);	//ONLY USED in WIDE_GUARDBAND

//TODO: This function may not be necessary
__device__ inline float RGB2Gray(float4 rgb);

__device__ inline float4 XYZ2RGB(float4 xyz);
__device__ inline float4 RGB2XYZ(float4 rgb);
__global__ void ShowRGBfromXYZ(float4* target, float4* source, int w, int h);
__global__ void ShowXYZfromRGB(float4* target, float4* source, int w, int h);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Suppose to get dM = rgb2gray(target), dM2 = 1-dM, dP = chroma(low_res_target), dP2 = 1 - dP
__global__ void InitializeM(float4 *M, int w, int h, int K);
__global__ void InitializeP(float4 *P, int w, int h, int K);	//w and h are in Primary array unit
__global__ void SimulateBacklight(float4* Backlight, float4* P, int ImageWidth, int ImageHeight, int K, int LEDRadius);

__device__ inline float Gaussian(int2 Dist);
__device__ float4 saturate(float4 val);// Overload with float4


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Nonnegative Matrix Factorization code below
__global__ void SolveForModulation(float4* Rec, float4* Ixyz, float4* M, float4* BL, int w, int h, int K, float Lambda)
{
	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	if (x >= w || y >= h)	return;
	// Calculate residual, which is rec+Rec2-Target. Also retrieve the diffused backlight corresponding to the pixel
	float4 rec			= Rec[y*w + x];
	float4 residual		= rec - Ixyz[y*w + x];
	float4 backlight	= BL[y*w + x];

	// TODO: Figure out the vectorization here
	// M -= (PtR)/(PtP)
	float4 m		= M[y*w + x];
	float4 nom	= backlight*residual;
	float4 denom = (backlight*backlight) + 1e-3;
	m -= nom / denom;

	// Finally saturate the value so that it's physically plausible. Note need to do qualtization for low-bits
	M[y*w + x] = saturate(m);
}

__global__ void SolveForPrimary(float4* Rec, float4* Ixyz, int ImageWidth, int ImageHeight, int K, float4* M, float4* P)
{
	//32*32 = 1024 is the maximum number of thread supported, xyz for nom and w for denom!
	__shared__ float4 cache[32 * 32];			const float4 zero ={ 0 };
	cache[threadIdx.y * 32 + threadIdx.x] = zero;
	__syncthreads();

	int2 LedUV		= make_int2(int(blockIdx.x), int(blockIdx.y));
	int2 LocalXY	= (make_int2(threadIdx.x, threadIdx.y) - 16)*3.0;	//sample more sparsely for realtime perf.

	// The global coordinate of the pixel thread. The thread can be outside the image boundary, be careful.
	int2 GlobalXY	=  LocalXY + (LedUV*K + K / 2);	//local coordinate plus LED center coordinate	

	if (GlobalXY.x >= 0 && GlobalXY.x < ImageWidth && GlobalXY.y >= 0 && GlobalXY.y < ImageHeight)
	{
		// Start Processing
		float4	rec		= Rec[GlobalXY.y*ImageWidth + GlobalXY.x];
		float4	residual= rec - Ixyz[GlobalXY.y*ImageWidth + GlobalXY.x];

		float4	m		= M[GlobalXY.y*ImageWidth + GlobalXY.x];
		float	weight	= Gaussian(LocalXY);

		//somehow the XYZ2RGB isnt very effective to bring the residual from XYZ2RGB...
		cache[threadIdx.y * 32 + threadIdx.x]		= XYZ2RGB(residual*m*weight);	//Nominator
		cache[threadIdx.y * 32 + threadIdx.x].w	= (m.x*m.x + m.y*m.y + m.z*m.z + m.w*m.w)*weight + 1e-3;	//Nominator
	}

	// Start 2-dimensional reduction, make sure every step from now on is synchronized
	__syncthreads();
	for (int stride = 16; stride >= 1; stride/=2)
	{
		if (threadIdx.x < stride && threadIdx.y < stride)
		{
			cache[threadIdx.y * 32 + threadIdx.x] += cache[(threadIdx.y) * 32 + (threadIdx.x + stride)];	//2X, 1Y
			cache[threadIdx.y * 32 + threadIdx.x] += cache[(threadIdx.y + stride) * 32 + (threadIdx.x)];	//1X, 2Y
			cache[threadIdx.y * 32 + threadIdx.x] += cache[(threadIdx.y + stride) * 32 + (threadIdx.x + stride)];	//2X, 2Y
		}
		__syncthreads();
	}

	// Now only thread 0 represent the LED diode; However, if more blocks are used, we need atomicadd cache[0]
	// And also use the LED_ID to uniquely identify the only thread.
	if (threadIdx.x == 0 && threadIdx.y == 0)	//Only the first thread process the remaining data
	{
		//now update Primary
		float4 p = P[LedUV.y*(ImageWidth / K) + LedUV.x];
		p -=  cache[0]/ (cache[0].w + 1e-6);
		P[LedUV.y*(ImageWidth / K) + LedUV.x] = saturate(p);
	}
}


int		FirstTime = 1;
bool	InitializedX = false;

extern "C"
void InitializeSolverMemory(int width, int height, int ratio)
{
	cudaChannelFormatDesc desc = cudaCreateChannelDesc<float4>();
	checkCudaErrors(cudaBindTexture2D(0, Target, dImageRGB, desc, width, height, pitch));	//bind dImageRGB to rgbaTex
	dim3 GridSizeP(((width / ratio) + 32 - 1) / 32, ((height / ratio) + 32 - 1) / 32);
	dim3 GridSizeM((width + 32 - 1) / 32, (height + 32 - 1) / 32);
	dim3 BlockSize(32, 32);

	InitializeP <<< GridSizeP, BlockSize >>>(dP, width / ratio, height / ratio, ratio);
	InitializeM <<< GridSizeM, BlockSize >>>(dM, width, height, ratio);

	SimulateBacklight <<< GridSizeM, BlockSize >>>	(dBL, dP, width, height, ratio, 6);
	BuildRecFromSimulatedBL <<< GridSizeM, BlockSize >>>	(dRec, dM, dBL, width, height);		//just initialization

	InitializedX = false;
}


extern "C"
double HdrVrHmdSolver(int* LAB_PHASE, int* STEP, float4 *dDest, int width, int height, int ratio, StopWatchInterface *timer, int val, float lambda)
{
	cudaChannelFormatDesc desc = cudaCreateChannelDesc<float4>();

	dim3 GridSizeP(width / ratio, height / ratio);	//the grid size should be the number of the LEDs used in the solver ..... times guard-band size

	dim3 GridSizeM((width + 32 - 1) / 32, (height + 32 - 1) / 32);
	dim3 BlockSize(32, 32);

	if (FirstTime)
	{
		InitializeSolverMemory(width, height, ratio);
		FirstTime = 0;
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Solve the NMF problem for Modulation and Primary	
	{
		// solve for Modulation, 2 inner iteration acceleration global convergence
		for (int InnerIter = 0; InnerIter < 2; InnerIter++)
		{
			SolveForModulation <<< GridSizeM, BlockSize >>>	(dRec, dImageXYZ, dM, dBL, width, height, ratio, lambda);	//rank 1
			BuildRecFromSimulatedBL <<< GridSizeM, BlockSize >>>	(dRec, dM, dBL, width, height);		//Rebuild Reconstruction 1
		}

		// solve for Primaries, 2 inner iteration acceleration global convergence
		for (int InnerIter = 0; InnerIter < 2; InnerIter++)
		{
			SolveForPrimary <<< GridSizeP, BlockSize >>>	(dRec, dImageXYZ, width, height, ratio, dM, dP);
			SimulateBacklight <<< GridSizeM, BlockSize >>>	(dBL, dP, width, height, ratio, 6);
			BuildRecFromSimulatedBL <<< GridSizeM, BlockSize >>>	(dRec, dM, dBL, width, height);		//Rebuild Reconstruction 1
		}
	}

	checkCudaErrors(cudaUnbindTexture(Target));

	// Switch what to show on screen.
	switch (val)
	{
	case 0:		ShowRGBfromXYZ <<<GridSizeM, BlockSize >>>		(dDest, dRec, width, height);								break;
	case 1:		ShowRGBfromXYZ <<<GridSizeM, BlockSize >>>		(dDest, dImageXYZ, width, height);								break;
	case 2:		checkCudaErrors(cudaMemcpy(dDest, dM, sizeof(float4)*width*height, cudaMemcpyDeviceToDevice)); break;
	case 3:		checkCudaErrors(cudaMemcpy(dDest, dBL, sizeof(float4)*width*height, cudaMemcpyDeviceToDevice)); break;
	}

	return 0;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helper functions
__device__ inline float Gaussian(int2 Dist)
{
	Dist *= Dist;
	return DENOM_C*exp(-(Dist.x + Dist.y) / (2.f*SIGMA*SIGMA));
}

// Overload with float4
__device__ float4 saturate(float4 val)
{
	return make_float4(saturate(val.x), saturate(val.y), saturate(val.z), saturate(val.w));
}

__global__ void ShowModulation(float4 *od, float4* M, int w, int h)
{
	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	od[y*w + x] = M[y*w + x];
}

__global__ void ShowBacklight(float4* od, float4* BL, int w, int h)
{
	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	od[y*w + x] = BL[y*w + x];
	
}

__global__ void BuildRecFromSimulatedBL(float4 *Rec, float4* M, float4* BL, int w, int h)
{
	int2 GlobalXY = make_int2(blockIdx.x*blockDim.x + threadIdx.x, blockIdx.y*blockDim.y + threadIdx.y);
	// Note since we solve for the primary in RGB space, but the objective function is in XYZ space.
	Rec[GlobalXY.y*w + GlobalXY.x] = RGB2XYZ(M[GlobalXY.y*w + GlobalXY.x] * BL[GlobalXY.y*w + GlobalXY.x]);
}

// Image edges darkening to avoid overfitting of the primary...
__global__ void InitializeTargetImage(float4* Target, int ImageWidth, int ImageHeight, int K)
{
	int2 GlobalXY	= make_int2(blockIdx.x*blockDim.x + threadIdx.x, blockIdx.y*blockDim.y + threadIdx.y);

	if (GlobalXY.x < K || GlobalXY.x >= ImageWidth - K || GlobalXY.y < K || GlobalXY.y >= ImageHeight - K)
	{
		float4 Pixel = Target[GlobalXY.y * ImageWidth + GlobalXY.x];
		float dX = (K - GlobalXY.x  > GlobalXY.x - (ImageWidth - K)) ? K - GlobalXY.x : GlobalXY.x - (ImageWidth - K);
		float dY = (K - GlobalXY.y  > GlobalXY.y - (ImageHeight - K)) ? K - GlobalXY.y : GlobalXY.y - (ImageHeight - K);
		float d = (dX > dY) ? dX : dY;
		float	spread	= exp(-(d*d) / (2.f*SIGMA*SIGMA));
		Target[GlobalXY.y * ImageWidth + GlobalXY.x] = Pixel*spread;
	}
}

extern "C"
void freeTextures()
{
	//Data array
	checkCudaErrors(cudaFree(dM));
	checkCudaErrors(cudaFree(dP));

	//Intermediate variables
	checkCudaErrors(cudaFree(dRec));
	checkCudaErrors(cudaFree(dBL));
	checkCudaErrors(cudaFree(dImageRGB));
	checkCudaErrors(cudaFree(dImageXYZ));

	checkCudaErrors(cudaFree(dTemp));
}

extern "C"
void initTexture(int width, int height, int K, float *hImage, float *hSubImage)
{
	// Allocatte data array
	checkCudaErrors(cudaMalloc(&dM, sizeof(float4)*width*height));
	checkCudaErrors(cudaMalloc(&dP, sizeof(float4)*(width)*(height)));	//allocate smaller memory seems to cause problem, perhaps MallocPitch?

	// Allocatte intermediate variables
	checkCudaErrors(cudaMalloc(&dRec, sizeof(float4)*width*height));
	checkCudaErrors(cudaMalloc(&dBL, sizeof(float4)*width*height));

	// Create target image and apply edge darkening to avoid over fitting problem
	checkCudaErrors(cudaMallocPitch(&dImageRGB, &pitch, sizeof(float4)*width, height));
	checkCudaErrors(cudaMallocPitch(&dImageXYZ, &pitch, sizeof(float4)*width, height));

	checkCudaErrors(cudaMemcpy2D(dImageRGB, pitch, hImage, sizeof(float4)*width, sizeof(float4)*width, height, cudaMemcpyHostToDevice));
	dim3 GridSizeM((width + 32 - 1) / 32, (height + 32 - 1) / 32);
	dim3 BlockSize(32, 32);
	InitializeTargetImage <<< GridSizeM, BlockSize >>>	(dImageRGB, width, height, K);
	ShowXYZfromRGB <<< GridSizeM, BlockSize >>>	(dImageXYZ, dImageRGB, width, height);

	checkCudaErrors(cudaMalloc(&dTemp, sizeof(float4)*width*height));
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Suppose to get dM = rgb2gray(target), dM2 = 1-dM, dP = chroma(low_res_target), dP2 = 1 - dP
__global__ void InitializeM(float4* M, int w, int h, int K)
{
	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	if (x >= w || y >= h)	return;
	M[y*w + x] = tex2D(Target, x + 0.5, y + 0.5);
}

__global__ void InitializeP(float4 *P, int w, int h, int K)	//w and h are in Primary array unit
{
	int u = blockIdx.x*blockDim.x + threadIdx.x;
	int v = blockIdx.y*blockDim.y + threadIdx.y;
	if (u >= w || v >= h)		return;

	float4 one = {1, 1, 1, 1};
	float4 zero = {0};
	//float4 pixel = tex2D(Target, u*K + K/2+0.5, v*K + K/2+0.5);
	float4 pixel = zero;
	for (int r = -K / 2; r <= K / 2; r++)
	{
		for (int c = -K / 2; c <= K / 2; c++)
		{
						pixel += tex2D(Target, u*K + K/2+0.5 + r, v*K + K/2+0.5 + c) / (K*K);
		}
	}

	P[v*w + u] = (pixel + 1.0)*0.5;
}

__global__ void SimulateBacklight(float4* Backlight, float4* P, int ImageWidth, int ImageHeight, int K, int LEDRadius)
{
	//32*32 = 1024 is the maximum number of thread supported, xyz for nom and w for denom!
	__shared__ float3 cache[64 * 64];	//(ImageWidth/K)*(ImageHeight/K)			
	cache[(threadIdx.y*2+0)*64 + threadIdx.x*2+0].x = P[(threadIdx.y*2+0)*64 + threadIdx.x*2+0].x;	//x,y
	cache[(threadIdx.y*2+0)*64 + threadIdx.x*2+0].y = P[(threadIdx.y*2+0)*64 + threadIdx.x*2+0].y;	//x,y
	cache[(threadIdx.y*2+0)*64 + threadIdx.x*2+0].z = P[(threadIdx.y*2+0)*64 + threadIdx.x*2+0].z;	//x,y

	cache[(threadIdx.y*2+0)*64 + threadIdx.x*2+1].x = P[(threadIdx.y*2+0)*64 + threadIdx.x*2+1].x;	//x+1,y
	cache[(threadIdx.y*2+0)*64 + threadIdx.x*2+1].y = P[(threadIdx.y*2+0)*64 + threadIdx.x*2+1].y;	//x+1,y
	cache[(threadIdx.y*2+0)*64 + threadIdx.x*2+1].z = P[(threadIdx.y*2+0)*64 + threadIdx.x*2+1].z;	//x+1,y

	cache[(threadIdx.y*2+1)*64 + threadIdx.x*2+0].x = P[(threadIdx.y*2+1)*64 + threadIdx.x*2+0].x;	//x,y+1
	cache[(threadIdx.y*2+1)*64 + threadIdx.x*2+0].y = P[(threadIdx.y*2+1)*64 + threadIdx.x*2+0].y;	//x,y+1
	cache[(threadIdx.y*2+1)*64 + threadIdx.x*2+0].z = P[(threadIdx.y*2+1)*64 + threadIdx.x*2+0].z;	//x,y+1

	cache[(threadIdx.y*2+1)*64 + threadIdx.x*2+1].x = P[(threadIdx.y*2+1)*64 + threadIdx.x*2+1].x;	//x+1,y+1
	cache[(threadIdx.y*2+1)*64 + threadIdx.x*2+1].y = P[(threadIdx.y*2+1)*64 + threadIdx.x*2+1].y;	//x+1,y+1
	cache[(threadIdx.y*2+1)*64 + threadIdx.x*2+1].z = P[(threadIdx.y*2+1)*64 + threadIdx.x*2+1].z;	//x+1,y+1
	// cache[(threadIdx.y * 2 + 0) * 64 + threadIdx.x * 2 + 0] = P[(threadIdx.y * 2 + 0) * 64 + threadIdx.x * 2 + 0];	//x,y
	// cache[(threadIdx.y * 2 + 0) * 64 + threadIdx.x * 2 + 1] = P[(threadIdx.y * 2 + 0) * 64 + threadIdx.x * 2 + 1];	//x+1,y
	// cache[(threadIdx.y * 2 + 1) * 64 + threadIdx.x * 2 + 0] = P[(threadIdx.y * 2 + 1) * 64 + threadIdx.x * 2 + 0];	//x,y+1
	// cache[(threadIdx.y * 2 + 1) * 64 + threadIdx.x * 2 + 1] = P[(threadIdx.y * 2 + 1) * 64 + threadIdx.x * 2 + 1];	//x+1,y+1


	__syncthreads();

	//USE SHARED MEMORY TO ACCELERATE THIS PART, SINCE 7x7 = 49 access is simply too much...
	int2 GlobalXY	= make_int2(blockIdx.x*blockDim.x + threadIdx.x, blockIdx.y*blockDim.y + threadIdx.y);
	if (GlobalXY.x >= ImageWidth || GlobalXY.y >= ImageHeight)	return;

	int2 NeighborUV;

	// Diffusion based backlight
	float4 AccumulatedPixel = {0};
	for (int r = -3; r <= 3; r++)
	{
		for (int c = -3; c <= 3; c++)
		{
			// Locate the neighbor LED indices and their center locations
			NeighborUV.x = int(GlobalXY.x / K) + c; 	NeighborUV.y = int(GlobalXY.y / K) + r;

			// Calculate the corresponding gaussian weighting/spreading. Outside boundaries doesn't count
			float spread = Gaussian(NeighborUV*K + K / 2 - GlobalXY);
			if (NeighborUV.x >= 0 && NeighborUV.x < ImageWidth / K && NeighborUV.y >= 0 && NeighborUV.y < ImageHeight / K)
			{
				float3 cacheval = cache[NeighborUV.y*(ImageWidth / K) + NeighborUV.x];

				AccumulatedPixel.x += spread*cacheval.x;	
				AccumulatedPixel.y += spread*cacheval.y;	
				AccumulatedPixel.z += spread*cacheval.z;
			}
		}
	}
	Backlight[GlobalXY.y*ImageWidth + GlobalXY.x] = (AccumulatedPixel);
}


__device__ inline float RGB2Gray(float4 rgb)
{
	return (0.2989 * rgb.x + 0.5870 * rgb.y + 0.1140 * rgb.z)*0.8 + 0.2;	//rgb2gray in Matlab
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// COLOR TRANSFORM FUNCTIONS

//D65	
//Matlab, note CIEXYZ can be > 1, so you need to divide by white point
// 
__device__ inline float4 XYZ2RGB(float4 xyz)
{
	float4 rgb ={ 0 };
	const float4 Row1 ={ 1, 0, 0, 0 };	//Optimization in RGB space instead of XYZ
	const float4 Row2 ={ 0, 1, 0, 0 };
	const float4 Row3 ={ 0, 0, 1, 0 };

	//sRGB D65
	//const float4 Row1 = { 3.2406,-1.5372,-0.4986, 0};
	//const float4 Row2 = {-0.9689, 1.8758, 0.0415, 0};
	//const float4 Row3 = { 0.0557,-0.2040, 1.0570, 0};

	rgb.x = dot(Row1, xyz);
	rgb.y = dot(Row2, xyz);
	rgb.z = dot(Row3, xyz);
	return rgb;
}

__device__ inline float4 RGB2XYZ(float4 rgb)
{
	float4 xyz ={ 0 };

	const float4 Row1 ={ 1, 0, 0, 0 };	//Optimization in RGB space instead of XYZ
	const float4 Row2 ={ 0, 1, 0, 0 };
	const float4 Row3 ={ 0, 0, 1, 0 };

	//sRGB D65
	//const float4 Row1 = {0.4124, 0.3576, 0.1805, 0};
	//const float4 Row2 = {0.2126, 0.7152, 0.0722, 0};
	//const float4 Row3 = {0.0193, 0.1192, 0.9505, 0};

	xyz.x = dot(Row1, rgb);
	xyz.y = dot(Row2, rgb);
	xyz.z = dot(Row3, rgb);
	return xyz;
}

// RGB2XYZ. Assuming WhitePoint D65
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
__global__ void ShowRGBfromXYZ(float4* target, float4* source, int w, int h)
{
	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	if (x >= w || y >= h)	return;
	target[y*w + x] = XYZ2RGB(source[y*w + x]);
}

__global__ void ShowXYZfromRGB(float4* target, float4* source, int w, int h)
{
	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	if (x >= w || y >= h)	return;
	target[y*w + x] = RGB2XYZ(source[y*w + x]);//out;
}

extern "C"
void GetModulationLayer(float4* target, int width, int height, int k)
{
	checkCudaErrors(cudaMemcpy(target, dM, sizeof(float4)*width*height, cudaMemcpyDeviceToHost));
}

extern "C"
void GetPrimaryLayer(float4* target, int width, int height, int ratio, int k)
{
	checkCudaErrors(cudaMemcpy(target, dP, sizeof(float4)*(width/ratio)*(height/ratio), cudaMemcpyDeviceToHost));
}

extern "C"
void GetSimulatedBLLayer(float4* target, int width, int height, int k)
{
	checkCudaErrors(cudaMemcpy(target, dBL, sizeof(float4)*width*height, cudaMemcpyDeviceToHost));
}

extern "C"
void GetRecLayer(float4* target, int width, int height, int k)
{
	dim3 GridSizeM((width + 32 - 1) / 32, (height + 32 - 1) / 32);
	dim3 BlockSize(32, 32);
	ShowRGBfromXYZ <<<GridSizeM, BlockSize >>>		(dTemp, dRec, width, height);
	checkCudaErrors(cudaMemcpy(target, dTemp, sizeof(float4)*width*height, cudaMemcpyDeviceToHost));
}