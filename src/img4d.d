module img4d;
import std.stdio,
       std.array,
       std.bitmanip,
       std.zlib,
       std.conv,
       std.algorithm,
       std.range,
       std.math;
import std.file : read, exists;
import std.digest.crc : CRC32,crc32Of;
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

private  PNG_Header read_IHDR(ref ubyte[] header,ref int idx){ 
    PNG_Header IHDR = {
        data_crc           : header[idx-4 .. idx+13],
        width              : header[idx .. idx+=4].peek!int(),
        height             : header[idx .. idx+=4].peek!int(),
        bit_depth          : header[idx],
        color_type         : header[idx+=1],
        compression_method : header[idx+=1],
        filter_method      : header[idx+=1],
        interlace_method   : header[idx+=1],
        crc                : header[idx+=1 .. idx+=4],
    };
    length_per_pixel = IHDR.color_type == 6 ? 4 : 3;  
    crc_check(IHDR.crc, IHDR.data_crc);
    return IHDR;
}

private int read_data_chunk_len(ref ubyte[] data, ref int idx){
  return data[idx .. idx+4].peek!int();
}

private string read_chunk_type(ref ubyte[] data,in int type_idx){
    return cast(string)data[type_idx .. type_idx+4];
}

private ubyte[] read_idat(ref ubyte[]data,in int idx,in int length){
    ubyte[] data_crc = [0x49, 0x44, 0x41, 0x54];
    data_crc ~= data[idx .. length];
    ubyte[] crc = data[length .. length+4];
    crc_check(crc, data_crc);
    return data[idx .. length];
}

private void crc_check(ubyte[]crc, in ubyte[]chunk){
    reverse(crc[]);
    if (crc != crc32Of(chunk)){
          throw new Exception("invalid");
    }

}

int PaethPredictor(int left, int upper, int upper_left)
{
    int paeth = left + upper - upper_left;
    int paeth_left = abs(paeth - left);    
    int paeth_upper = abs(paeth - upper);    
    int paeth_upper_left = abs(paeth - upper_left);    
    if (paeth_left <= paeth_upper && paeth_left <= paeth_upper_left)
        return left;
    if (paeth_upper <= paeth_upper_left)
        return upper;   
    return upper_left;
}

private int normalize_pixel_value(int value){ return value < 256 ? value : value - 256; }

auto inverse_filtering(ref ubyte[][] data){
    ubyte[][][] arr_rgb;  
    int[][][] comp_data;
    int[] filtering_type;
    int[][] actual_data;
    
    data.each!(sc => filtering_type ~= sc.front);
    data.each!(sc => arr_rgb ~= [sc.remove(0).chunks(length_per_pixel).array]);
	
    foreach(idx,sc_data; arr_rgb){
        int[] temp;
        int[] predictor;
        int[] actual_data_back;

        switch(filtering_type[idx]){           
            case 0:
                sc_data.each!(a => a.each!(b => temp ~= b));	
            	actual_data ~= [temp.array];
                
            	break;
            
            case 1:
                actual_data ~= [sc_data.front.walkLength.iota
                                .map!(i => transversal(sc_data, i).chain.cumulativeFold!"a + b < 256 ?  a + b : a + b - 256")]
                                .join.transposed.join;
            	break;
            
            case 2:
                sc_data.each!(a => a.each!(b => temp~= b));
                actual_data ~= [(temp[] += actual_data.back[]).map!(a => a.normalize_pixel_value).array];

                break;
	    
            case 3:
                actual_data_back = actual_data.back;
                auto up = chunks(actual_data_back, length_per_pixel);
                auto current = chunks(sc_data, length_per_pixel);
                int[] up_pixel = *cast(int[]*)&up;
            	sc_data.popFront;            		
            	auto sc = sc_data.join;
                up[0].each!((idx,n) =>temp ~= ((n/2) + current[0][0][idx]).normalize_pixel_value);

                up_pixel[length_per_pixel .. $].each!((o,n)=>  
                                temp ~= (((temp[o] + n)/2) + sc[o]).normalize_pixel_value);

                actual_data ~= [temp];
                break;

            case 4:
                auto joined = sc_data.join;

                actual_data.back[0 .. length_per_pixel]
                                .each!((idx,a) => temp ~= (a + joined[idx]).normalize_pixel_value);
                
                actual_data.back[length_per_pixel .. $]
                                .each!((idx, a) => 
                                temp ~= (PaethPredictor(temp[idx], a, actual_data.back[idx]) 
                                + joined[idx + length_per_pixel]).normalize_pixel_value);
            
                actual_data ~= [temp];
                break;

  	    default:
                break;
        }       
    }
    return actual_data;
}
 

auto parse(ref PNG_Header info, string filename){
    if(!exists(filename))
        throw new Exception("Not found the file.");
    ubyte[] data = cast(ubyte[]) read(filename);
    string[] ancillary_chunks = ["tRNS","gAMA","cHRM","sRGB","iCCP","tEXt","zTXt",
                                "iTXt","bKGD","pHYs","vpAg","sBIT","sPLT","hIST","tIME",
                                "fRAc","gIFg","gIFt","gIFx","oFFs","pCAL","sCAL"];
    int idx = 0;
    int sig_size = 8;
    int length_size = 4;

    int length;
    int img_height;
    string chunk_type;
    int[][] actual_data;
    ubyte[] idat; 
    ubyte[]unc_idat;

    if (data[idx .. sig_size] != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        throw new Exception("Invalid PNG format.");
    
    idx += sig_size;
    while (idx >= 0){
        length = read_data_chunk_len(data, idx);
        chunk_type = read_chunk_type(data, idx+length_size);
        idx += 8;
        switch(chunk_type){
            case "IHDR":
                info = read_IHDR(data, idx);
                break;
            
            case "IDAT":
                idat = read_idat(data, idx, idx+length);
                idx+=length+4;
                UnCompress uc = new UnCompress(HeaderFormat.deflate);
                unc_idat ~= cast(ubyte[])uc.uncompress(idat.dup);
                int num_scanline = unc_idat.length / info.height;
                auto chunks =chunks(unc_idat, num_scanline).array;
                ubyte[][] unc_chunks= *cast(ubyte[][]*)&chunks;
                actual_data = inverse_filtering(unc_chunks);
                break;
          
            case "IEND": 
                idx = -1; // To end while() loop
                break;

            default:  // except for IHDR, IDAT, IEND
                  if (!ancillary_chunks.canFind(chunk_type))
                      throw new Exception("Invalid png format"); 
                  //writeln(chunk_type);
                  idx += length+4;
        }
    }
        return actual_data; 
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
