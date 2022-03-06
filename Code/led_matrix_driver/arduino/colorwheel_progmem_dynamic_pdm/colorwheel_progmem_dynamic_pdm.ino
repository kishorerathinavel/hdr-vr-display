// colorwheel_progmem demo for Adafruit RGBmatrixPanel library.
// Renders a nice circle of hues on our 32x32 RGB LED matrix:
// http://www.adafruit.com/products/607

// This version uses precomputed image data stored in PROGMEM
// rather than calculating each pixel.  Nearly instantaneous!  Woo!

// Written by Limor Fried/Ladyada & Phil Burgess/PaintYourDragon
// for Adafruit Industries.
// BSD license, all text above must be included in any redistribution.
#include <Adafruit_GFX.h>   // Core graphics library
#include "RGBmatrixPanel_dynamic_pdm.h" // Hardware-specific library
#include <SPI.h>				// needed for Arduino versions later than 0018
#include <Ethernet.h>
#include <EthernetUdp.h>			// UDP library from: bjoern@cs.stanford.edu 12/30/2008
#include "test.h"
// #include "value05.h"

// If your 32x32 matrix has the SINGLE HEADER input,
// use this pinout:
#define CLK 11  // MUST be on PORTB! (Use pin 11 on Mega)
#define OE  9
#define LAT 10
#define A   A0
#define B   A1
#define C   A2
#define D   A3
// If your matrix has the DOUBLE HEADER input, use:
//#define CLK 8  // MUST be on PORTB! (Use pin 11 on Mega)
//#define LAT 9
//#define OE  10
//#define A   A3
//#define B   A2
//#define C   A1
//#define D   A0
RGBmatrixPanel matrix(A, B, C, D, CLK, LAT, OE, false);

void setup() {
  Serial.begin(9600);

  int     i, len;
  uint8_t *ptr = matrix.backBuffer();	// Get address of matrix data
  // memcpy_P(ptr, img1, sizeof(img1));
  // for(int j = 0; j < sizeof(img1); j++) {
  //   ptr[j] = img1[j];
  // }
  // ptr = matrix.backBuffer();
  
  // for(int j = 0; j < sizeof(img1); j++) {
  //   Serial.println(ptr[j]);
  // }
  // memset(ptr, 17, sizeof(img1)/2);
  memset(ptr, 17, 32*32*sizeof(uint8_t));

  // Start up matrix AFTER data is copied.  The RGBmatrixPanel
  // interrupt code ties up about 40% of the CPU time, so starting
  // it now allows the prior drawing code to run even faster!
  matrix.begin();
}

void loop() {
}
