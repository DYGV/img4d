import std.stdio,
       std.array,
       std.bitmanip,
       std.zlib,
       std.conv,
       std.algorithm,
       std.range;
import std.file : read, exists;
import std.digest.crc : CRC32,crc32Of;
import std.range.primitives;
import std.algorithm.mutation;

int length_per_pixel;

void main(){}

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

auto inverse_filtering(ref ubyte[] data){
    int[] actual_data;
    int[][] arr_rgb;
    int need_to_fill_num; 
    int type = data[0];
   
    data.remove(0);
    need_to_fill_num = data.length % length_per_pixel;

    if(need_to_fill_num != 0){
        foreach(i; need_to_fill_num .. length_per_pixel)
            data ~= 0;
    }
    
    switch(type){
        case 0: // None
            data.each!(a => actual_data ~= a );
            return actual_data;

      /*  case 1: // Sub
            break;
        case 2: // Up
            break;
        case 3: // Average
            break;
        case 4: // Paeth
            break;  */
        
        // Sub filter
        default:
            auto chunk = chunks(data, length_per_pixel);
            chunk.front.walkLength.iota
                .map!(i => transversal(chunk, i))
                .each!(arr => arr_rgb ~= chain(arr).cumulativeFold!
                "a + b < 256 ?  a + b : a + b - 256".array);
            
            return arr_rgb.front.walkLength.iota
                      .map!(i => transversal(arr_rgb, i)).join;
          
    }
} 

auto parse(string filename){
    if(!exists(filename))
        throw new Exception("Not found the file.");
    ubyte[] data = cast(ubyte[]) read(filename);
    string[] ancillary_chunks = ["tRNS","gAMA","cHRM","sRGB","iCCP","tEXt","zTXt",
                                "iTXt","bKGD","pHYs","vpAg","sBIT","sPLT","hIST","tIME",
                                "fRAc","gIFg","gIFt","gIFx","oFFs","pCAL","sCAL"];
    int idx = 0;
    int sig_size = 8;
    int length_size = 4;
    int rgb=void;

    int length;
    string chunk_type;
    ubyte[] idat, unc_idat;
    int img_height;
    int [][][] actual_data;
    PNG_Header info;

    if (data[idx .. sig_size] != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        throw new Exception("Invalid PNG format.");
    
    idx += sig_size;
    while (idx >= 0){
        length = read_data_chunk_len(data, idx);
        chunk_type = read_chunk_type(data, idx+length_size);
        idx += 8;
        switch(chunk_type){
            case "IHDR":
                writeln("In IHDR");
                info = read_IHDR(data, idx);
                writefln("Width  %8d\nHeight  %7d",
                          info.width,
                          info.height);
                writefln("Bit Depth  %4d\nColor Type  %3d",
                          info.bit_depth, 
                          info.color_type, 
                          info.compression_method);
                break;
            
            case "IDAT":
                writeln("In IDAT");
                idat = read_idat(data, idx, idx+length);
                idx+=length+4;
                UnCompress uc = new UnCompress(HeaderFormat.deflate);
                unc_idat ~= cast(ubyte[])uc.uncompress(idat.dup);
                if(unc_idat.length % info.height!=0)
                    throw new Exception("there is something wrong with length of uncompressed idat");
                int bpp = unc_idat.length / info.height;
                auto chunks = chunks(unc_idat, bpp);
                write("filter type method => ");
                chunks.each!(a => write(a.front,","));  // filter method per line  
                
                chunks.each!(a => actual_data ~= inverse_filtering(a).chunks(length_per_pixel).array);
                break;
          
            case "IEND": 
                writeln("In IEND");
                idx = -1; // To end while() loop
                break;

            default:  // except for IHDR, IDAT, IEND
                  if (!ancillary_chunks.canFind(chunk_type))
                      throw new Exception("Invalid png format"); 
                  writeln(chunk_type);
                  idx += length+4;
        }
    }
}

unittest{
    ubyte[] IHDR_hex = [0x49, 0x48, 0x44, 0x52];
    ubyte[] IDAT_hex = [0x49, 0x44, 0x41, 0x54];
    ubyte[] IEND_hex = [0x49, 0x45, 0x4E, 0x44];
    assert(read_chunk_type(IHDR_hex, 0) == "IHDR");
    assert(read_chunk_type(IDAT_hex, 0) == "IDAT");
    assert(read_chunk_type(IEND_hex, 0) == "IEND");

    parse("../png_img/lena.png");
}

