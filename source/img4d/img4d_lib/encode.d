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

ubyte scanlineFilterType;

ubyte[] makeIHDR(Header header){
    ubyte depth,
          colorSpaceType,
          compress,
          filterType,
          adam7;

    with(header){
        depth           = bitDepth.to!ubyte;
        colorSpaceType  = colorType.to!ubyte;
        compress        = compressionMethod.to!ubyte;
        filterType      = filterMethod.to!ubyte;
        adam7           = interlaceMethod.to!ubyte;
    }

    const ubyte[] sig = [0x89, 0x50, 0x4E,0x47, 0x0D, 0x0A, 0x1A, 0x0A];  
    const ubyte[] bodyLenIHDR = [0x0, 0x0, 0x0, 0x0D];
    ubyte[] chunkIHDR = [0x49, 0x48, 0x44, 0x52, // "IHDR"
                          0x0, 0x0, 0x0, 0x00, // width
                          0x0, 0x0, 0x0, 0x00, // height
                          depth, colorSpaceType, 
                          compress, filterType, adam7];
    chunkIHDR[4 .. 8].append!uint(header.width);
    chunkIHDR[8 .. 12].append!uint(header.height);

    ubyte[] IHDR = bodyLenIHDR ~ chunkIHDR ~ chunkIHDR.makeCrc;
    return sig ~ IHDR;
}

ubyte[] makeIDAT(ref Pixel pix,ref Header header){
    Compress cmps = new Compress(HeaderFormat.deflate);
    ubyte[] beforeCmpsData, idatData, chunkData, IDAT;
    uint chunkSize;
    ubyte[][] byteData;
    const ubyte[] chunkType = [0x49, 0x44, 0x41, 0x54];
    ubyte[] bodyLenIDAT = [0x0, 0x0, 0x0, 0x0];

    with(header){
        with(colorTypes){
            if(colorType == grayscale || colorType == grayscaleA){
                byteData.length = pix.grayscale.length;
            }else{
                byteData.length = pix.R.length;    
            }
        }
    }

    //pix.Pixel.each!((idx,a) => byteData[idx] = a.to!(ubyte[]));
    pix.choiceFilterType.each!((idx,a) => byteData[idx] = a.to!(ubyte[]));
    byteData.each!(a => beforeCmpsData ~= a.padLeft(scanlineFilterType, a.length+1).array);
    idatData ~= cast(ubyte[])cmps.compress(beforeCmpsData);
    idatData ~= cast(ubyte[])cmps.flush();
    chunkSize = idatData.length.to!uint;
    
    bodyLenIDAT[0 .. 4].append!uint(chunkSize);
    chunkData = chunkType ~ idatData;
    IDAT = bodyLenIDAT ~ chunkData ~ chunkData.makeCrc;
    return IDAT;
}


pure ubyte[] makeAncillary(){
    throw new Exception("Not implemented.");
}

pure ubyte[] makeIEND(){
    const ubyte[] chunkIEND = [0x0, 0x0, 0x0, 0x0];
    const ubyte[] chunkType = [0x49, 0x45, 0x4E, 0x44];
    ubyte[] IEND = chunkIEND ~chunkType ~  chunkType.makeCrc;

    return IEND;
}

pure auto makeCrc(in ubyte[] data){
    ubyte[4] crc;
    data.crc32Of.each!((idx,a) => crc[3-idx] = a);
    return crc;
}

// defective
auto choiceFilterType(ref Pixel pix){
    int[] sumNone,
          sumSub,
          sumUp,
          sumAve,
          sumPaeth;
    ubyte [][] R, G, B, A,
              filteredNone,
              filteredSub,
              filteredUp,
              filteredAve,
              filteredPaeth;

    /* begin comparison with none, sub, up, ave and paeth*/
        
    if(!pix.grayscale.empty){
        filteredNone = pix.grayscale.dup;
        filteredSub = pix.grayscale.sub;
    }else{
        filteredNone = pix.Pixel.dup;
                
        R = pix.R.sub;
        G = pix.G.sub;
        B = pix.B.sub;
        A = pix.A.sub;

        filteredSub = Pixel(R, G, B).Pixel;
    } 
    sumNone = cast(int[])(filteredNone.map!(a => a.sum).array);
    sumSub = cast(int[])(filteredSub.map!(a => a.sum).array);



    /* end comparison with none, sub, up, ave and paeth*/
    scanlineFilterType = filterTypes.Sub;
    return filteredSub;
}
