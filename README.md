This repository contains code to design and implement a high dynamic range virtual reality display. The key challenge is to reduce the render-to-display latency. The repository contains:

- code to simulate motion blur that arises from different hdr display backlight modulation schemes
- code to decompose a HDR scene into two images: one high resoution image that can be displayed on an LCD panel and one low resolution image that can be displayed on an LED matrix display. The decomposition is implemented using CUDA.
- code to calibrate the display for gamma correction
- code to implement an LED matrix display driver using a system of PC, GPU, arduino, and fpga. The GPU sends data to the LCD panel. The PC sends data to the arduino which in turn sends data to the FPGA which ultimately drives the individual rows of the LED matrix display.
- simulation and prototype image results. Unfortunately, video results are too large to upload. I can share them if you reach out to me.