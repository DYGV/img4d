module img4d_encode;
import img4d;
import std.stdio,
       std.array,
       std.bitmanip,
       std.conv,
       std.digest.crc;

ubyte[] make_IHDR(ref PNG_Header info){
    ubyte depth = info.bit_depth.to!ubyte;
    ubyte colorType = info.color_type.to!ubyte;
    ubyte compress = info.compression_method.to!ubyte;
    ubyte filterType = info.filter_method.to!ubyte;
    ubyte adam7 = info.interlace_method.to!ubyte;
    
    ubyte[] sig = [0x89, 0x50, 0x4E,0x47, 0x0D, 0x0A, 0x1A, 0x0A];  
    ubyte[] body_len_IHDR = [0x0,0x0,0x0,0x0D];
    ubyte[] chunks_IHDR = [0x49 ,0x48, 0x44, 0x52, // "IHDR"
                          0x0, 0x0, 0x0, 0x00, // width
                          0x0, 0x0, 0x0, 0x00, // height
                          depth, colorType, 
                          compress, filterType, adam7];
    chunks_IHDR[4 .. 8].append!uint(info.width);
    chunks_IHDR[8 .. 12].append!uint(info.height);

    ubyte[] IHDR = body_len_IHDR ~ chunks_IHDR ~ chunk_maker(chunks_IHDR);
    return sig ~ IHDR; 
}

ubyte[] make_IEND(){
    ubyte[] chunks_IEND = [0x0,0x0,0x0,0x0, 0x49 ,0x45 ,0x4E ,0x44];
    ubyte[] IEND =  chunks_IEND ~ chunk_maker(chunks_IEND);
    return IEND;
}

auto chunk_maker(ubyte[] data){
    auto crc = crc32Of(data);
    return crc;
}
