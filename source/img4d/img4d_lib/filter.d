module img4d_lib.filter;
import img4d;
import std.stdio,
       std.array,
       std.conv,
       std.algorithm,
       std.range,
       std.math;
import std.range.primitives;
import std.algorithm.mutation;

pure ref auto inverseSub(ref ubyte[][] scanline){
    return [scanline.joinVertical.map!(
            .cumulativeFold!((a,b) => 
                  a + b < 256
                ? a + b
                : a + b - 256))].join.transposed;
}

pure ubyte[][] sub(ref ubyte[][] src){
    if(src.empty) return src;

    return src.neighborDifference;
}

pure ubyte[][] up(ref ubyte[][] src){
    if(src.empty) return src;

    ubyte[][] diff = src.joinVertical
                        .neighborDifference;

    return diff.joinVertical;
}

  /**
   *  Calculate difference neighbor pixel.
   */
pure ubyte[][] neighborDifference(ubyte[][] src){
    ubyte[][] difference;
    difference.length = src.length;
    src.each!((idx,a) =>  difference[idx] ~= src[idx].front);

    src.map!(a => a.slide(2))
         .each!((idx,b) => difference[idx] ~= 
             b.map!(b=> b.front - b.back)
             .map!(c =>
                      c > 0
                      ? 256 - c 
                      : c.abs
                  )
             .array.to!(ubyte[]));
    return difference;
}

  /**
   *  To vertical array 
   */
pure ref auto joinVertical(T)(ref T[][] src){
    return src.front.walkLength.iota.map!(i => transversal(src,i).array).array;
}

auto inverseUp(){}

auto ave(){}
auto inverseAve(){}

auto paeth(){}
auto inversePaeth(){}


