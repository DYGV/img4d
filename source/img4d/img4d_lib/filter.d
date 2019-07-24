module img4d_lib.filter;

import std.stdio, std.array, std.conv, std.algorithm, std.range, std.math;

pure ref auto inverseSub(ref ubyte[][] scanline)
{
  return [scanline.joinVertical.map!(.cumulativeFold!((a, b) => a + b < 256 ? a + b : a + b - 256))]
    .join.transposed;
}

pure ref auto inverseSub(ref ubyte[][] scanline, bool gray)
{
  return [scanline.map!(.cumulativeFold!((a, b) => a + b < 256 ? a + b : a + b - 256))]
    .join.transposed;
}

ref auto ubyte[][] sub(ref ubyte[][] src)
{
  ubyte[][] output;
  output.length = src.length;
  foreach (idx, scanline; src)
  {
    foreach (edx, sc; scanline)
    {
      if (edx == 0)
      {
        output[idx] ~= sc;
      }
      else
      {
        output[idx] ~= (sc - scanline[edx - 1]).normalizePixelValue;
      }
    }
  }
  return output;
}

ref auto ubyte[][] up(ref ubyte[][] src)
{
  ubyte[][] output;
  output.length = src.length;
  foreach (idx, scanline; src)
  {
    if (idx == 0)
    {
      output[idx] ~= scanline;
    }
    else
    {
      scanline.each!((edx, a) => output[idx] ~= (a - src[idx - 1][edx])
          .normalizePixelValue.to!ubyte);
    }
  }
  return output;
}

/**
   *  Calculate difference neighbor pixel.
   */
pure ref auto neighborDifference(ref ubyte[][] src)
{

  return src.map!(a => a.slide(2))
    .map!(b => b.front.front ~ b.map!(c => c.front - c.back)
        .map!(d => d > 0 ? 256 - d : d.abs)
        .array
        .to!(ubyte[]))
    .array;
}

/**
   *  To vertical array 
   */
pure ref auto T[][] joinVertical(T)(ref T[][] src)
{
  return src.front.walkLength.iota.map!(i => transversal(src, i).array).array;
}

auto inverseUp()
{
}

/**
   *  Average(x) = Raw(x) - floor((Raw(x-bpp)+Prior(x))/2)
   */
ubyte[][] ave(ref ubyte[][] src)
{
  if (src.length == 0)
  {
    return src;
  }

  ubyte[][] output;
  output.length = src.length;
  output.front = src.front;

  foreach (idx, scanline; src[1 .. $])
  {
    scanline.each!((edx, a) => output[idx + 1] ~= edx == 0 ? (a - (src[idx].front / 2)).normalizePixelValue
        : (a - (src[idx][edx] + src[idx + 1][edx - 1]) / 2).normalizePixelValue);
  }
  return output;
}

ubyte normalizePixelValue(int value)
{
  if (value < 0)
  {
    value += 256;
  }
  else if (value >= 256)
  {
    value -= 256;
  }
  return value.to!ubyte;
}

auto inverseAve()
{
}

//  Paeth(x) = Raw(x) - PaethPredictor(Raw(x-bpp), Prior(x), Prior(x-bpp))
ubyte[][] paeth(ref ubyte[][] src)
{
  if (src.length == 0)
    return src;
  ubyte[][] output;
  output.length = src.length;
  output.front = src.front;

  foreach (idx, scanline; src[1 .. $])
  {
    scanline.each!((edx, a) => output[idx + 1] ~= edx == 0 ? (a - paethPredictor(src[idx].front)).normalizePixelValue
        : (a - paethPredictor(src[idx][edx], src[idx + 1][edx - 1], src[idx][edx - 1]))
        .normalizePixelValue);
  }
  return output;
}

template paethPredictor()
{
  int paethPredictor(int upper, int left = 0, int upperLeft = 0)
  {
    int paeth = left + upper - upperLeft;
    int paethLeft = abs(paeth - left);
    int paethUpper = abs(paeth - upper);
    int paethUpperLeft = abs(paeth - upperLeft);
    if (paethLeft <= paethUpper && paethLeft <= paethUpperLeft)
      return left;
    if (paethUpper <= paethUpperLeft)
      return upper;
    return upperLeft;
  }
}

auto inversePaeth()
{
}
