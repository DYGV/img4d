import std.stdio,
       std.array,
       std.bitmanip,
       std.zlib,
       std.conv,
       std.algorithm,
       std.range;
import std.file : read, exists;
import std.digest.crc : CRC32,crc32Of;
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

private PNG_Header read_IHDR(ref ubyte[] header,ref int idx){ 
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
      
    crc_check(IHDR.crc, IHDR.data_crc);
    return IHDR;
}

int read_data_chunk_len(ref ubyte[] data,ref int idx){
  return data[idx .. idx+4].peek!int();
}
string  read_chunk_type(ref ubyte[] data,int type_idx){
    return cast(string)data[type_idx .. type_idx+4];
}

ubyte[] read_idat(ref ubyte[]data,int idx,int length){
    ubyte[] data_crc = [0x49, 0x44, 0x41, 0x54];
    data_crc ~= data[idx .. length];
    ubyte[] crc = data[length .. length+4];
    crc_check(crc, data_crc);
    return data[idx .. length];
}

void crc_check(ubyte[]crc, in ubyte[]chunk){
  reverse(crc[]);
  if (crc != crc32Of(chunk)){
        throw new Exception("invalid");
    }
}

auto inverse_filtering(ref ubyte[] data){
    int type = data[0];
    data.remove(0); // => actual data 
    switch(type){
        case 0: // None
          break;
        case 1: // Sub
            break;
        case 2: // Up
            break;
        case 3: // Average
            break;
        case 4: // Paeth
            break;
        default:
            break;
    }
} 

auto parse(string filename){
    if(!exists(filename))
        throw new Exception("Not found the file.");
    ubyte[] data = cast(ubyte[]) read(filename);
    int idx = 0;
    int sig_size = 8;
    int length_size = 4;
    int length;
    string chunk_type;
    ubyte[] idat, unc_idat;
    int img_height;

    if (data[idx .. sig_size] != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        throw new Exception("Invalid PNG format.");
    
    idx += sig_size;
    while (idx >= 0){
        length = read_data_chunk_len(data, idx);
        chunk_type = read_chunk_type(data, idx+length_size);
        idx+=8;
        switch(chunk_type){
            case "IHDR":
                writeln("In IHDR");
                PNG_Header info = read_IHDR(data, idx);
                writefln("Width  %8d\nHeight  %7d",
                          info.width,
                          info.height);
                writefln("Bit Depth  %4d\nColor Type  %3d",
                          info.bit_depth, 
                          info.color_type, 
                          info.compression_method);
                img_height = info.height;
                break;
            
            case "IDAT":
                writeln("In IDAT");
                idat = read_idat(data, idx, idx+length);
                idx+=length+4;
                UnCompress uc = new UnCompress(HeaderFormat.deflate);
                unc_idat ~= cast(ubyte[])uc.uncompress(idat.dup);
                if(unc_idat.length % img_height!=0)
                    throw new Exception("there is something wrong with length of uncompressed idat");
                int bpp = unc_idat.length / img_height;
                auto chunks = chunks(unc_idat, bpp);
                write("filter type method => ");
                chunks.each!(a => write(a.front,","));  // filter method per line  
                chunks.each!(a => a.inverse_filtering);
                writeln();
                break;
          
            case "IEND": 
                writeln("In IEND");
                idx = -1; // To end while() loop
                break;

            default:  // except for IHDR, IDAT, IEND
                writeln(chunk_type);
                idx += length+4;
                
        }
    }
}

unittest{
   parse("../png_img/lena.png");
}


