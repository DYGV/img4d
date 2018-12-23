module img4d_lib.encode;
import img4d;
import std.stdio,
       std.array,
       std.bitmanip,
       std.conv,
       std.zlib,
       std.digest,
       std.digest.crc,
       std.range,
       std.algorithm;

ubyte[] makeIHDR(Header info){
    ubyte depth = info.bitDepth.to!ubyte;
    ubyte colorType = info.colorType.to!ubyte;
    colorType.writeln;
    ubyte compress = info.compressionMethod.to!ubyte;
    ubyte filterType = info.filterMethod.to!ubyte;
    ubyte adam7 = info.interlaceMethod.to!ubyte;
    const ubyte[] sig = [0x89, 0x50, 0x4E,0x47, 0x0D, 0x0A, 0x1A, 0x0A];  
    const ubyte[] bodyLenIHDR = [0x0, 0x0, 0x0, 0x0D];
    ubyte[] chunkIHDR = [0x49, 0x48, 0x44, 0x52, // "IHDR"
                          0x0, 0x0, 0x0, 0x00, // width
                          0x0, 0x0, 0x0, 0x00, // height
                          depth, colorType, 
                          compress, filterType, adam7];
    chunkIHDR[4 .. 8].append!uint(info.width);
    chunkIHDR[8 .. 12].append!uint(info.height);

    ubyte[] IHDR = bodyLenIHDR ~ chunkIHDR ~ chunkIHDR.makeCrc;
    return sig ~ IHDR;
}
ubyte[] makeIDAT(T)(T[][] actualData, Header info){
    if(actualData == null) throw new Exception("null reference exception");

    Compress cmps = new Compress(HeaderFormat.deflate);
    ubyte[] beforeCmpsData, idatData, chunkData, IDAT; 
    ubyte filterType = filterType.None; // only None filter you can apply in current

    uint chunkSize;
    ubyte[][] byteData = minimallyInitializedArray!(ubyte[][])(actualData.length, actualData[0].length);
    const ubyte[] chunkType = [0x49, 0x44, 0x41, 0x54];
    ubyte[] bodyLenIDAT = [0x0, 0x0, 0x0, 0x0];
    
    version(none){
        import img4d_lib.filter;
        ubyte filterType = 0;
        ubyte[][] byteData;
        ubyte[][][] rgb;
        actualData.each!(sc => rgb ~= cast(ubyte[][])[sc.chunks(lengthPerPixel).array]);
        rgb.each!((idx,a) =>byteData~= (sub!("-",">=0","+")(a)).join.to!(ubyte[]));
    }

    actualData.each!((idx,a) => byteData[idx] = a.to!(ubyte[]));
    
    if(info.colorType == 0 || info.colorType == 4){
        idatData = byteData.join;
        chunkSize = idatData.length.to!uint;
    }else{
        byteData.each!(a => beforeCmpsData ~= a.padLeft(filterType, a.length+1).array);
        idatData ~= cast(ubyte[])cmps.compress(beforeCmpsData);
        idatData ~= cast(ubyte[])cmps.flush();
        chunkSize = idatData.length.to!uint;
    }
    bodyLenIDAT[0 .. 4].append!uint(chunkSize);
    chunkData = chunkType ~ idatData;
    IDAT = bodyLenIDAT ~ chunkData ~ chunkData.makeCrc;
    return IDAT;
}


ubyte[] makeAncillary(){
    throw new Exception("Not implemented.");
}

ubyte[] makeIEND(){
    const ubyte[] chunkIEND = [0x0, 0x0, 0x0, 0x0];
    const ubyte[] chunkType = [0x49, 0x45, 0x4E, 0x44];
    ubyte[] IEND = chunkIEND ~chunkType ~  chunkType.makeCrc;

    return IEND;
}

auto makeCrc(in ubyte[] data){
    ubyte[4] crc;
    data.crc32Of.each!((idx,a) => crc[3-idx] = a);
    return crc;
}
