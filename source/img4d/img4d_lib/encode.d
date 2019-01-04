module img4d_lib.encode;
import img4d,
       img4d_lib.filter;
import std.stdio,
       std.array,
       std.bitmanip,
       std.conv,
       std.zlib,
       std.digest,
       std.digest.crc,
       std.range,
       std.algorithm;

ubyte filterType;

ubyte[] makeIHDR(Header header){
    ubyte depth = header.bitDepth.to!ubyte;
    ubyte colorType = header.colorType.to!ubyte;
    ubyte compress = header.compressionMethod.to!ubyte;
    ubyte filterType = header.filterMethod.to!ubyte;
    ubyte adam7 = header.interlaceMethod.to!ubyte;
    const ubyte[] sig = [0x89, 0x50, 0x4E,0x47, 0x0D, 0x0A, 0x1A, 0x0A];  
    const ubyte[] bodyLenIHDR = [0x0, 0x0, 0x0, 0x0D];
    ubyte[] chunkIHDR = [0x49, 0x48, 0x44, 0x52, // "IHDR"
                          0x0, 0x0, 0x0, 0x00, // width
                          0x0, 0x0, 0x0, 0x00, // height
                          depth, colorType, 
                          compress, filterType, adam7];
    chunkIHDR[4 .. 8].append!uint(header.width);
    chunkIHDR[8 .. 12].append!uint(header.height);

    ubyte[] IHDR = bodyLenIHDR ~ chunkIHDR ~ chunkIHDR.makeCrc;
    return sig ~ IHDR;
}

ubyte[] makeIDAT(Pixel pix, Header header){

    Compress cmps = new Compress(HeaderFormat.deflate);
    ubyte[] beforeCmpsData, idatData, chunkData, IDAT; 
    //filterType = filterType.None;
    
    uint chunkSize;
    ubyte[][] byteData;
    const ubyte[] chunkType = [0x49, 0x44, 0x41, 0x54];
    ubyte[] bodyLenIDAT = [0x0, 0x0, 0x0, 0x0];
    if(header.colorType == colorTypes.grayscale || header.colorType == colorTypes.grayscaleA){
        byteData.length = pix.grayscale.length;
    }else{
        byteData.length = pix.R[0].length;    
    }

    //pix.Pixel.each!((idx,a) => byteData[idx] = a.to!(ubyte[]));
    pix.choiceFilterType.each!((idx,a) => byteData[idx] = a.to!(ubyte[]));
    byteData.each!(a => beforeCmpsData ~= a.padLeft(filterType, a.length+1).array);
    idatData ~= cast(ubyte[])cmps.compress(beforeCmpsData);
    idatData ~= cast(ubyte[])cmps.flush();
    chunkSize = idatData.length.to!uint;
    
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

// defective
auto choiceFilterType(Pixel pix){
    int sumSub,
        sumUp,
        sumAve,
        sumPaeth;
    ubyte [][] actualSub;

    filterType = filterTypes.Sub;
    
    if(!pix.grayscale.empty){
        return pix.grayscale.sub;
    }
    ubyte [][] R = pix.R.sub;
    ubyte [][] G = pix.G.sub;
    ubyte [][] B = pix.B.sub;
    //ubyte [][] A = pix.A.sub;
    ubyte[][] sub = Pixel(R, G, B).Pixel;

    /* compare up ave .........*/
    return sub;
}
