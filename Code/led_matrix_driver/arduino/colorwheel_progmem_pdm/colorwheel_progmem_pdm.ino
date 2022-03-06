// colorwheel_progmem demo for Adafruit RGBmatrixPanel library.
// Renders a nice circle of hues on our 32x32 RGB LED matrix:
// http://www.adafruit.com/products/607

// This version uses precomputed image data stored in PROGMEM
// rather than calculating each pixel.  Nearly instantaneous!  Woo!

// Written by Limor Fried/Ladyada & Phil Burgess/PaintYourDragon
// for Adafruit Industries.
// BSD license, all text above must be included in any redistribution.
#include <Adafruit_GFX.h>   // Core graphics library
#include "RGBmatrixPanel_pdm.h" // Hardware-specific library

// #include "pdm_single_LED09.h"
#include "test.h"
// #include "test_2.h"
// #include "test_3.h"
// #include "testhdr.h"

// #include "img00.h"
// #include "img01.h"
// #include "img02.h"
// #include "img03.h"
// #include "img04.h"
// #include "img05.h"
// #include "img06.h"
// #include "img07.h"
// #include "img08.h"
// #include "img09.h"
// #include "img10.h"
// #include "img11.h"
// #include "img12.h"
// #include "img13.h"
// #include "img14.h"

// #include "value00.h"
// #include "value01.h"
// #include "value02.h"
// #include "value03.h"
// #include "value04.h"
// #include "value05.h"
// #include "value06.h"
// #include "value07.h"
// #include "value08.h"
// #include "value09.h"
// #include "value10.h"
// #include "value11.h"
// #include "value12.h"
// #include "value13.h"
// #include "value14.h"

// #include "all.h"
// #include "all5.h"
// #include "all6.h"
// #include "all12.h"
// #include "all14.h"
// #include "all15.h"
// #include "all16.h"


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
  int     i, len;
  uint8_t *ptr = matrix.backBuffer(); // Get address of matrix data

  // Copy image from PROGMEM to matrix buffer:
  memcpy_P(ptr, img1, sizeof(img1));

  // Start up matrix AFTER data is copied.  The RGBmatrixPanel
  // interrupt code ties up about 40% of the CPU time, so starting
  // it now allows the prior drawing code to run even faster!
  matrix.begin();
}

void loop() {
  // do nothing
}
