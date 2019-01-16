module img4d_lib.filter;
import img4d;
import std.stdio,
       std.array,
       std.conv,
       std.algorithm,
       std.range,
       std.math;

pure ref auto inverseSub(ref ubyte[][] scanline){
    return [scanline.joinVertical.map!(
            .cumulativeFold!((a,b) => 
                  a + b < 256
                ? a + b
                : a + b - 256))].join.transposed;
}

pure ref auto sub(ref ubyte[][] src){
    if(src.empty) return src;

    return src.neighborDifference;
}

pure ref auto up(ref ubyte[][] src){
    if(src.empty) return src;

    ubyte[][] srcVertical = src.joinVertical;
    ubyte[][] diff = srcVertical.neighborDifference;
    
    return diff.joinVertical;
}

  /**
   *  Calculate difference neighbor pixel.
   */
pure ref auto neighborDifference(ref ubyte[][] src){

    return src.map!(a => a.slide(2))
                  .map!(b  => b.front.front ~ 
                              b.map!(c => c.front - c.back)
                                          .map!(d =>
                                                    d > 0
                                                    ? 256 - d 
                                                    : d.abs
                                                ).array.to!(ubyte[])
                        ).array;
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


