module img4d_lib.color_space;
import img4d,
       std.stdio,
       std.array,
       std.conv,
       std.algorithm,
       std.range;

ref auto toGrayscale(T)(ref Header header, ref T[][][] color){
    with(header){
        with(colorTypes){
        if (colorType != trueColor && colorType != trueColorA) throw new Exception("invalid format.");
        if (colorType == trueColorA)
        color.each!((idx,a) => a.each!((edx,b) => color[idx][edx] = b.remove(3)));
        }
    }

    double[][] temp;
    ubyte[][] gray;
    double[] arr = [0.3, 0.59, 0.11];

    color.each!(a=> a.transposed
          .each!((idx,b)=> 
                  temp ~= b.map!(to!double)
                  .map!(h => h*=arr[idx]).array
                )
          );
    
    temp.chunks(3)
          .map!(v => v.transposed)
          .each!(h => gray ~= h.map!(n => n.sum).array.to!(ubyte[]).array);

    return Pixel(gray);
}

ref auto toGrayscale(T)(ref Header header, ref T[][][] color, bool fastMode){
    with(header){
        with(colorTypes){
        if (colorType != trueColor && colorType != trueColorA) throw new Exception("invalid format.");
        if (colorType == trueColorA)
        color.each!((idx,a) => a.each!((edx,b) => color[idx][edx] = b.remove(3)));
        }
    }

    ubyte[][] gray = color.map!(a => a.map!(sum).map!(a => a/3).array).array.to!(ubyte[][]);
    return Pixel(gray);
}

