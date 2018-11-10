module img4d;
import img4d_decode;
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

auto decode(ref PNG_Header info ,string filename){
  if(!exists(filename))
        throw new Exception("Not found the file.");
  return parse(info, filename);
}

auto to_grayscale(ref int[][][] color){
    ulong input_len = color[0][0].length; 
    if (input_len != 3 && input_len != 4) throw new Exception("invalid format.");
    if (input_len == 4)
        color.each!((idx,a) => a.each!((edx,b) => color[idx][edx] = b.remove(3)));
    
    double[][] temp;
    double[][] gray;
    double[] arr = [0.3, 0.59, 0.11];

    alias to_double = map!(to!double);
    
    color.each!(a=> a.transposed
          .each!((idx,b)=> temp ~= to_double(b)
          .map!(h => h*=arr[idx]).array));
    
    temp.chunks(3)
          .map!(v => v.transposed)
          .each!(h => gray ~= h.map!(n => n.sum).array);
    
    return gray;
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

float[][] differential(double[][] array, double[][] filter = [[-1, 0, -1],[-2, 0, 2],[-1, 0, 1]],
                                            double[][] v_filter= [[-1, -2, -1],[0, 0, 0],[1, 2, 1]]){
    // filter of default argument is sobel
    int image_h = array.length.to!int;
    int image_w = array[0].length.to!int;
    int vicinity_h = 3;
    int vicinity_w = 3;
    int h = vicinity_h / 2;
    int w = vicinity_w / 2;

    float[][]  output = minimallyInitializedArray!(float[][])(image_h, image_w);
    output.each!(a=> fill(a,0));
    foreach(i; h .. image_h-h){
        foreach(j;  w .. image_w-w){
            double t1 = 0;
            double t2 = 0;
              foreach(m; 0 .. vicinity_h){
                    foreach(n; 0 .. vicinity_w){      
                        t1 += array[i-h+m][j-w+n]*filter[m][n];
                        t2 += (array[i-h+m][j-w+n]*v_filter[m][n]);
                    }
                }
              output[i][j] = sqrt((( t1 < 0 ? 0 : t1).pow(2) + (t2 < 0 ? 0 : t2).pow(2)).to!float);
        }
    }
return output;
}

double[][] gradient(double[][] gradient_x, double[][] gradient_y, bool approximation = false){
    int image_h = gradient_x.length.to!int;
    int image_w = gradient_x[0].length.to!int;
    double[][] output = minimallyInitializedArray!(double[][])(image_h, image_w);
    double theta;
    foreach(h; 0 .. image_h){
        foreach(w; 0 .. image_w){
            theta = (atan2(gradient_x[h][w], gradient_y[h][w]) * 180) / PI;

            if(approximation){
                if(theta >= -22.5  && theta < 22.5)   theta = 0;
                if(theta >=  157.5 && theta < 180)    theta = 0;
                if(theta >= -180   && theta < -157.5) theta = 0; 
                if(theta >=  22.5  && theta < 67.5)   theta = 45;
                if(theta >= -157.5 && theta < -112.5) theta = 45;
                if(theta >=  67.5  && theta < 112.5)  theta = 90;
                if(theta >= -112.5 && theta < -67.5)  theta = 90;
                if(theta >=  112.5 && theta < 157.5)  theta = 135;
                if(theta >= -67.5  && theta < -22.5)  theta = 135;
            }
            output[h][w] = theta;
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
