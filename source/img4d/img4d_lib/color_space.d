module img4d_lib.color_space;
import std.stdio,
       std.array,
       std.conv,
       std.algorithm,
       std.range;

double[][] toGrayscale(T)(T[][][] color){
    uint input_len = color[0][0].length.to!uint; 
    if (input_len != 3 && input_len != 4) throw new Exception("invalid format.");
    if (input_len == 4)
        color.each!((idx,a) => a.each!((edx,b) => color[idx][edx] = b.remove(3)));
    
    double[][] temp, gray;
    double[] arr = [0.3, 0.59, 0.11];

    color.each!(a=> a.transposed
          .each!((idx,b)=> 
                  temp ~= b.map!(to!double)
                  .map!(h => h*=arr[idx]).array
                )
          );
    
    temp.chunks(3)
          .map!(v => v.transposed)
          .each!(h => gray ~= h.map!(n => n.sum).array);
    
    return gray;
}

