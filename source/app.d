import img4d;
import std.stdio, std.range, std.algorithm.iteration, std.process, img4d_lib.filter;

int main()
{
  Header beforeEncode;

  // start decode
  Pixel colorPix = beforeEncode.load("png_img/lena.png");
  if (colorPix.Pixel.length == 0)
  {
    return 0;
  }

  writefln("Width  %8d\nHeight  %7d", beforeEncode.width, beforeEncode.height);
  writefln("Bit Depth  %4d\nColor Type  %3d\n", beforeEncode.bitDepth, beforeEncode.colorType);

  Pixel grayPix = beforeEncode.rgbToGrayscale(colorPix, true);
  beforeEncode.colorType = colorTypes.grayscale;

  // start encode
  bool encodedData = beforeEncode.save(grayPix, "png_img/encoded_lena_1.png");

  //read encoded file
  Header afterEncode;

  Pixel encodedDataToDecode = afterEncode.load("png_img/encoded_lena_1.png");

  writefln("Width  %8d\nHeight  %7d", afterEncode.width, afterEncode.height);
  writefln("Bit Depth  %4d\nColor Type  %3d\n", afterEncode.bitDepth, afterEncode.colorType);

  return 0;
}
