import std.stdio, img4d;

int main(){
  Img4d img = new Img4d();
  // start decode
  Pixel colorPix = img.load("../../png_img/lena.png");
  writefln("Width  %8d\nHeight  %7d", img.header.width, img.header.height);
  writefln("Bit Depth  %4d\nColor Type  %3d\n", img.header.bitDepth, img.header.colorType);

  // start encode
  bool encodedData = img.save(colorPix, "../../png_img/encoded_lena_1.png");

  return 0;
}
