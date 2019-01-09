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
unittest{
    ubyte[][] filtered  = [[1, 1, 255], [255, 2, 3], [3, 2, 1]];
    ubyte[][] unFilter  = [[1, 1, 255], [0, 3, 2], [3, 5, 3]];
        
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
        assert(a.equal(unFilter[idx])));
    "unittest of Sub filter was passed".writeln;
}



pure ubyte[][] sub(ref ubyte[][] src){
    if(src.empty) return src;

    return src.neighborDifference;
}
unittest{
    ubyte[][] beforeCalculateSub = [[1, 2, 3],[9, 3, 0]];
    ubyte[][] subFiltered = [[1, 1, 1],[9, 250, 253]];
    assert(beforeCalculateSub.sub.equal(subFiltered));
}



pure ubyte[][] up(ref ubyte[][] src){
    if(src.empty) return src;

    ubyte[][] diff = src.joinVertical
                        .neighborDifference;

    return diff.joinVertical;
}
unittest{
    ubyte[][] beforeCalculateUp = [[1, 2, 3], [1, 5, 2]];
    // joinVertical => [[1, 1],[2, 5],[3, 2]]
    // neighborDifference
    // =>
    // front - back < 0 => abs(front - back)
    // front - back > 0 => 256 - (front - back)

    ubyte[][] upFiltered = [[1, 2, 3],[0, 3, 255]];
    assert(beforeCalculateUp.up.equal(upFiltered));

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
unittest{
    ubyte[][] beforeCalculateDiff = [[1, 2, 3],[9, 3, 0]];
    assert(beforeCalculateDiff.map!(a => a.slide(2).array)
      .equal([[[1, 2], [2, 3]], [[9, 3], [3, 0]]]));
    
    // front - back < 0 => abs(front - back)
    // front - back > 0 => 256 - (front - back)
    ubyte[][] diff  = [[1, 1, 1],
                      [9, 250, 253]];
    assert(beforeCalculateDiff.neighborDifference.equal(diff));
}



  /**
   *  To vertical array 
   */
pure ref auto joinVertical(T)(ref T[][] src){
    return src.front.walkLength.iota.map!(i => transversal(src,i).array).array;
}
unittest{
    ubyte[][] horizontal  = [[1, 2, 3],[4, 5, 6],[7, 8, 9]];
    ubyte[][] vertical    = [ [1,4,7],
                              [2,5,8],
                              [3,6,9] ];
    assert(horizontal.joinVertical.equal(vertical));
}



auto inverseUp(){}


auto ave(){}
auto inverseAve(){}


auto paeth(){}
auto inversePaeth(){}


