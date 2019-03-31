module img4d_lib.filter;

import std.stdio,
       std.array,
       std.conv,
       std.algorithm,
       std.range,
       std.math;

pure 
ref auto inverseSub(ref ubyte[][] scanline){
    return [scanline.joinVertical.map!(
            .cumulativeFold!((a,b) => 
                  a + b < 256
                ? a + b
                : a + b - 256))].join.transposed;
}

pure 
ref auto inverseSub(ref ubyte[][] scanline, bool gray){
    return [scanline.map!(
            .cumulativeFold!((a,b) => 
                  a + b < 256
                ? a + b
                : a + b - 256))].join.transposed;
}

pure 
ref auto ubyte[][] sub(ref ubyte[][] src){
    if(src.empty) return src;

    return src.neighborDifference;
}

pure 
ref auto ubyte[][] up(ref ubyte[][] src){
    if(src.empty) return src;

    ubyte[][] srcVertical = src.joinVertical;
    ubyte[][] diff = srcVertical.neighborDifference;
    
    return diff.joinVertical;
}

  /**
   *  Calculate difference neighbor pixel.
   */
pure 
ref auto neighborDifference(ref ubyte[][] src){

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
pure 
ref auto T[][] joinVertical(T)(ref T[][] src){
    return src.front.walkLength.iota.map!(i => transversal(src,i).array).array;
}

auto inverseUp(){}


  /**
   *  Average(x) = Raw(x) - floor((Raw(x-bpp)+Prior(x))/2)
   */
auto ave(ubyte[][] src){
    if(src.length == 0) return src;
    ubyte[][] joinTemp;
    auto output = [src.front];
    
    foreach(idx, scanline;src[1 .. $]){
      ubyte[] up = src[idx];
    	ubyte[] current = scanline;
	    ubyte upFirst = up.front / 2;
    	up.popFront;

    	joinTemp = [up, current];
    	auto verticalJoined = joinTemp.joinVertical;
    	ubyte[] ave  = [upFirst] ~  verticalJoined.map!(a => (a.front + a.back)/2).array.to!(ubyte[]);
  	
	    joinTemp = [ave, current];
	    verticalJoined =  joinTemp.joinVertical;
	    output ~= [verticalJoined.neighborDifference().map!(a => a.back).array.to!(ubyte[])];
    }
    return output;
}

auto inverseAve(){}

auto paeth(){}
auto inversePaeth(){}


