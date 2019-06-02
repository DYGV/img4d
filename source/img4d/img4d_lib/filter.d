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

pure ref auto ubyte[][] sub(ref ubyte[][] src)
{
  if (src.empty)
    return src;

  return src.neighborDifference;
}

pure ref auto ubyte[][] up(ref ubyte[][] src)
{
  if (src.empty)
    return src;

  ubyte[][] srcVertical = src.joinVertical;
  ubyte[][] diff = srcVertical.neighborDifference;

  return diff.joinVertical;
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
ubyte[][] ave(immutable ubyte[][] src)
{
  if (src.length == 0)
  {
    return src.to!(ubyte[][]);
  }
  ubyte[][] output = src.to!(ubyte[][]).dup;
  // src[0][1 .. $].each!((idx,a) => output[0][idx+1] = (a - (output[0][idx])/2).normalizePixelValues)
  foreach (idx, scanline; src[1 .. $])
  {
    scanline.each!((edx, a) => output[idx + 1][edx] = edx == 0 ? (a - (src[idx].front / 2)).normalizePixelValue
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

auto paeth()
{
}

auto inversePaeth()
{
}
