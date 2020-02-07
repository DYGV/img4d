import img4d;
import std.stdio, std.datetime.systime, img4d.img4d_lib.encode;
mixin bitOperator;
mixin makeChunk;

int main()
{
  Img4d img = new Img4d();
  // start decode
  Pixel colorPix = img.load("../../png_img/lena.png");
  writefln("Width  %8d\nHeight  %7d", img.header.width, img.header.height);
  writefln("Bit Depth  %4d\nColor Type  %3d\n", img.header.bitDepth, img.header.colorType);

  // start encode (you can save image with ancillary chunks)
  ubyte[] chunk_type = [116, 73, 77, 69]; // "tIME"
  SysTime date = Clock.currTime();
  // date.timeToChunkFormat.writeln;
  ubyte[] chunk = chunk_type.makeChunk(date.timeToChunkFormat);
  bool encodedData = img.save(colorPix, "../../png_img/encoded_lena_1.png", chunk);

  return 0;
}

ubyte[7] timeToChunkFormat(in SysTime systime)
{
  ubyte[7] time_chunk;
  set32bitInt(time_chunk[0 .. 2], systime.year);
  time_chunk[2] = systime.month;
  time_chunk[3] = systime.day;
  time_chunk[4] = systime.hour;
  time_chunk[5] = systime.minute;
  time_chunk[6] = systime.second;
  return time_chunk;
}
