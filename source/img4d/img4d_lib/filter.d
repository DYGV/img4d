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

pure auto inverseSub(ref ubyte[][] scanline){
    return [scanline.front.walkLength.iota
            .map!(i => transversal(scanline, i).chain
            .cumulativeFold!((a,b) => 
                  a + b < 256
                ? a + b
                : a + b - 256))].join.transposed;
}

pure ubyte[][] sub(ubyte[][] src){
    if(src.empty) return src;
    return src.neighborDifference;
}

pure ubyte[][] up(ubyte[][] src, ref Header header){
    if(src.empty) return src;

    return src.joinVertical
              .neighborDifference.joinVertical;
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


pure ubyte[][] joinVertical(T)(T[][] src){
    return cast(ubyte[][])(src.front.walkLength.iota.map!(i => transversal(src,i).array).array);
}

auto up(){}

auto ave(){}

auto paeth(){}

unittest{
    int[][] filtered = [[1, 1, 255], [255, 2, 3], [3, 2, 1]];
    int[][] before   = [[1, 1, 255], [0, 3, 2], [3, 5, 3]];
        
    /*
       sub filter
       the first pixel is intact  =>                1,1,1

         1 + 255 = 256 >= 256     =>  256 - 256 = 0  => 0
         1 +   2 =   3 <  256     =>                    3
       255 +   3 = 258 >  256     =>  258 - 256 = 2  => 2

         0 +   3 =   3 <  256     =>                    3
         3 +   2 =   5 <  256     =>                    5
         2 +   1 =   3 <  256     =>                    3
     */
    filtered.inverseSub.each!((idx,a) =>
        assert(a.equal(before[idx])));
    "unittest of Sub filter was passed".writeln;
}
