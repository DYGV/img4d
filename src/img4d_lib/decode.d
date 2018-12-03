module img4d_lib.decode;
import img4d, img4d_lib.filter;
import std.file : read;
import std.digest.crc : CRC32, crc32Of;
import std.stdio,
       std.array,
       std.bitmanip,
       std.zlib,
       std.conv,
       std.algorithm,
       std.range.primitives,
       std.algorithm.mutation,
       std.range,
       std.math;

private PNG_Header read_IHDR(ubyte[] header){ 
    ubyte[] chunk = header[0 .. 17];  // Chunk Type + Chunk Data 
    PNG_Header IHDR = {
        width              : header[4 .. 8].byte_to_int,
        height             : header[8 .. 12].byte_to_int,
        bit_depth          : header[12],
        color_type         : header[13],
        compression_method : header[14],
        filter_method      : header[15],
        interlace_method   : header[16],
        crc                : header[17 .. 21],
    };
    switch(IHDR.color_type){
        case 0:
            length_per_pixel = IHDR.width;
            break;
        case 2:
            length_per_pixel = 3;
            break;
        case 3:
            length_per_pixel = 3;
            break;
        case 4:
            length_per_pixel = IHDR.width * 2;
            break;
        case 6:
            length_per_pixel = 4;
            break;
        default:
            break;
    }

    crc_check(IHDR.crc, chunk);
    return IHDR;
}

private int byte_to_int(T)(T[] data){ return data.peek!int(); }

private string byte_to_string(T)(T[] data){ return cast(string)data; }

private ubyte[] read_idat(ubyte[] data){
    /*ubyte[] data_crc = data[0 .. $-4];
    ubyte[] crc = data[$-4 .. $];
    crc_check(crc, data_crc);*/
    return data[4 .. $-4];
}

private void crc_check(ubyte[] crc, in ubyte[] chunk){
    reverse(crc[]);
    if (crc != chunk.crc32Of){
          throw new Exception("invalid");
    }
}

private int PaethPredictor(int left, int upper, int upper_left){
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

private auto normalize_pixel_value(T)(T value){ return value < 256 ? value : value - 256; }

private int[][] inverse_filtering(string op, string inequality, string inv_op)(ref ubyte[][] data){
    ubyte[][][] arr_rgb;  
    int[][][] comp_data;
    int[] filtering_type;
    int[][] actual_data;
    data.each!(sc => filtering_type ~= sc.front);
    data.each!(sc => arr_rgb ~= [sc.remove(0).chunks(length_per_pixel).array]);

    foreach(idx, sc_data; arr_rgb){
        int[] temp;
        int[] predictor;
        int[] actual_data_back;

        switch(filtering_type[idx]){
            case 0:
                sc_data.each!(a => a.each!(b => temp ~= b));
            	actual_data ~= [temp.array];
                
            	break;
            
            case 1:
                actual_data ~=  Sub!(op,inequality,inv_op)(sc_data).join; 
            	break;
            
            case 2:
                sc_data.each!(a => a.each!(b => temp ~= b));
                actual_data ~= [(temp[] += actual_data.back[]).map!(a => a.normalize_pixel_value).array];

                break;
	    
            case 3:
                actual_data_back = actual_data.back;
                auto up = chunks(actual_data_back, length_per_pixel);
                auto current = chunks(sc_data, length_per_pixel);
                int[] up_pixel = *cast(int[]*)&up;
            	sc_data.popFront;            		
            	auto sc = sc_data.join;
                up.front.each!((idx,n) =>temp ~= ((n/2) + current.front[0][idx]).normalize_pixel_value);

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
                                    + joined[idx + length_per_pixel])
                              .normalize_pixel_value);
            
                actual_data ~= [temp];
                break;

  	    default:
                break;
        }       
    }
    return actual_data;
}
 

public int[][] parse(ref PNG_Header info, string filename){
    ubyte[] data = cast(ubyte[])filename.read;
    int idx       = 0;
    int sig_size  = 8;

    if (data[idx .. sig_size] != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        throw new Exception("Invalid PNG format.");
    
    int chunk_length_size = 4;
    int chunk_type_size   = 4;
    int chunk_crc_size    = 4;
    int chunk_data_size;
    string chunk_type;
    int[][] actual_data;
    ubyte[] unc_idat;
    const string[] ancillary_chunks = ["tRNS","gAMA","cHRM","sRGB","iCCP","tEXt","zTXt",
                                      "iTXt","bKGD","pHYs","vpAg","sBIT","sPLT","hIST","tIME",
                                      "fRAc","gIFg","gIFt","gIFx","oFFs","pCAL","sCAL"];
    
    idx += sig_size;
    UnCompress uc = new UnCompress(HeaderFormat.deflate);
    while (idx >= 0){
        chunk_data_size = data[idx .. idx+chunk_length_size].byte_to_int;
        idx += chunk_length_size;
        chunk_type = data[idx .. idx+chunk_type_size].byte_to_string;

        switch(chunk_type){
            case "IHDR":
              int end_idx = chunk_type_size + chunk_data_size + chunk_crc_size;
              info = data[idx .. idx + end_idx].read_IHDR;
              idx += end_idx;
              break;
            
            case "IDAT":
                int end_idx = chunk_data_size + chunk_crc_size;
                ubyte[] idat = data[idx .. idx + end_idx].read_idat;
                idx += chunk_length_size + end_idx;

                if(info.color_type == 0 || info.color_type == 4){
                    length_per_pixel = info.width;
                    actual_data ~= idat.chunks(length_per_pixel).array.to!(int[][]);
                    break;
                }

                unc_idat ~= cast(ubyte[])uc.uncompress(idat.dup);
                break;
          
            case "IEND": 
                idx = -1; // To end while() loop
                break;

            default:  // except for IHDR, IDAT, IEND
                if (!ancillary_chunks.canFind(chunk_type))
                      throw new Exception("Invalid png format"); 
                //writeln(chunk_type);
                idx += chunk_type_size + chunk_data_size + chunk_crc_size;
        }
    }
    if(unc_idat.length == 0 || info.color_type == 0 || info.color_type == 4) 
        return actual_data;
   
    uint num_scanline = (unc_idat.length / info.height).to!uint;
    auto chunks = unc_idat.chunks(num_scanline).array;
    ubyte[][] unc_chunks = (*cast(ubyte[][]*)&chunks).array;
    actual_data = inverse_filtering!("+","<256","-")(unc_chunks);

    return actual_data; 
}

