import img4d;
import std.stdio, std.range, std.algorithm.iteration, std.datetime.systime, img4d_lib.filter, img4d_lib.encode;

mixin bitOperator;
mixin makeChunk;

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

  // start encode (you can save image with ancillary chunks)
  ubyte[] chunk_type = [116, 73, 77, 69]; // "tIME"
  SysTime date = Clock.currTime();
  // date.timeToChunkFormat.writeln;
  ubyte[] chunk =  chunk_type.makeChunk(date.timeToChunkFormat);
  bool encodedData = beforeEncode.save(grayPix, "png_img/encoded_lena_1.png", chunk);

  //read encoded file
  Header afterEncode;

  Pixel encodedDataToDecode = afterEncode.load("png_img/encoded_lena_1.png");

  writefln("Width  %8d\nHeight  %7d", afterEncode.width, afterEncode.height);
  writefln("Bit Depth  %4d\nColor Type  %3d\n", afterEncode.bitDepth, afterEncode.colorType);


  return 0;
}

ubyte[7] timeToChunkFormat(in SysTime systime){
  ubyte[7] time_chunk;
  set32bitInt(time_chunk[0 .. 2], systime.year);
  time_chunk[2] = systime.month;
  time_chunk[3] = systime.day;
  time_chunk[4] = systime.hour;
  time_chunk[5] = systime.minute;
  time_chunk[6] = systime.second;
  return time_chunk;
}
