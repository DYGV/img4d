module img4d;
import img4d_lib.decode,
       img4d_lib.encode,
       img4d_lib.filter,
       img4d_lib.color_space;
import std.stdio,
       std.array,
       std.bitmanip,
       std.conv,
       std.algorithm,
       std.range,
       std.math;
import std.file : exists;
import std.range.primitives;
import std.algorithm.mutation;

int length_per_pixel;

struct PNG_Header {
    ubyte[] data_crc;
    int     width,
            height,
            bit_depth,
            color_type,
            compression_method,  
            filter_method,
            interlace_method;
    ubyte[] crc; 
}

auto decode(ref PNG_Header info, string filename){
    if(!exists(filename))
        throw new Exception("Not found the file.");
    return parse(info, filename);
}

ubyte[] encode(ref PNG_Header info,  int[][] color){
    if(color == null) throw new Exception("null reference exception");
    ubyte[] data = info.make_IHDR ~ color.make_IDAT(info) ~ make_IEND;
    return data;
}

double[][] rgb_to_grayscale(ref int[][][] color){
    return to_grayscale(color);
}

int[][] to_binary(ref double[][] gray, double threshold=127){
  // Simple thresholding 

  int[][] bin;
  gray.each!(a =>bin ~=  a.map!(b => b < threshold ? 0 : 255).array);
  return bin;
}

int[][] to_binarize_elucidate(T)(T[][] array, string process="binary"){
    int image_h = array.length.to!int;
    int image_w = array[0].length.to!int;
    int vicinity_h = 3;
    int vicinity_w = 3;
    int h = vicinity_h / 2;
    int w = vicinity_w / 2;
    
    int[][] output = minimallyInitializedArray!(int[][])(image_h, image_w);
    output.each!(a=> fill(a,0));
    
    foreach(i; h .. image_h-h){
        foreach(j;  w .. image_w-w){
            if (process=="binary"){
                int t = 0;
                foreach(m; 0 .. vicinity_h){
                    foreach(n; 0 .. vicinity_w){      
                        t += array[i-h+m][j-w+n];
                    }
                }
                if((t/(vicinity_h*vicinity_w)) < array[i][j]) output[i][j] = 255;
            }              
            else if(process == "median"){
                int[] t;
                foreach(m; 0 .. vicinity_h){
                    foreach(n; 0 .. vicinity_w){      
                        t ~= array[i-h+m][j-w+n].to!int;
                    }
                }    
                output[i][j] = t.sort[4];
            }  
        }
    }
    return output;
}

double[][] differ(ref double[][] origin, ref double[][] target){
    double[][] diff;
    origin.each!((idx,a) => diff ~=  (target[idx][] -= a[]).map!(b => abs(b)).array);

    return diff;
}

int[][] mask(ref int[][][] color_target, ref int[][] gray){
    int[][] masked;
    masked.length = gray.length;
    gray.each!((idx,a)=> a.each!((edx,b) => masked[idx] ~= b==255 ? color_target[idx][edx] : [0, 0, 0]));
  
    return masked;
}
