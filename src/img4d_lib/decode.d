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

private Header readIHDR(ubyte[] header){
    if(header.length != 21) throw new Exception("invalid header format");
    ubyte[] chunk = header[0 .. 17];  // Chunk Type + Chunk Data 
    Header IHDR = {
        width             : header[4 .. 8].byteToInt,
        height            : header[8 .. 12].byteToInt,
        bitDepth          : header[12],
        colorType         : header[13],
        compressionMethod : header[14],
        filterMethod      : header[15],
        interlaceMethod   : header[16],
        crc               : header[17 .. 21],
    };
    switch(IHDR.colorType){
        case colorType.grayscale:
            lengthPerPixel = IHDR.width;
            break;
        case colorType.trueColor:
            lengthPerPixel = 3;
            break;
        case colorType.indexColor:
            lengthPerPixel = 3;
            break;
        case colorType.grayscaleA:
            lengthPerPixel = IHDR.width * 2;
            break;
        case colorType.trueColorA:
            lengthPerPixel = 4;
            break;
        default:
            break;
    }

    crcCheck(IHDR.crc, chunk);
    return IHDR;
}

private int byteToInt(ubyte[] data){ return data.peek!int(); }

private string byteToString(T)(T[] data){ return cast(string)data; }

private ubyte[] readIDAT(ubyte[] data){
    version(none){
        ubyte[] dataCrc = data[0 .. $-4];
        ubyte[] crc = data[$-4 .. $];
        crcCheck(crc, dataCrc);
    }
    return data[4 .. $-4];
}

private void crcCheck(ubyte[] crc, in ubyte[] chunk){
    reverse(crc[]);
    if (crc != chunk.crc32Of){
          throw new Exception("invalid");
    }
}

private int paethPredictor(int left, int upper, int upperLeft){
    int paeth = left + upper - upperLeft;
    int paethLeft = abs(paeth - left);
    int paethUpper = abs(paeth - upper);
    int paethUpperLeft = abs(paeth - upperLeft);
    if (paethLeft <= paethUpper && paethLeft <= paethUpperLeft)
        return left;
    if (paethUpper <= paethUpperLeft)
        return upper;   
    return upperLeft;
}

private auto normalizePixelValue(T)(T value){ return value < 256 ? value : value - 256; }

private int[][] inverseFiltering(string op, string inequality, string inverseOp)(ref ubyte[][] data){
    ubyte[][][] rgb;
    int[][][] compData;
    int[] filters;
    int[][] actualData;
    data.each!(sc => filters ~= sc.front);
    data.each!(sc => rgb ~= [sc.remove(0).chunks(lengthPerPixel).array]);

    foreach(idx, scanline; rgb){
        int[] temp;
        int[] predictor;
        int[] actualDataBack;

        switch(filters[idx]){
            case filterType.None:
                scanline.each!(a => a.each!(b => temp ~= b));
            	actualData ~= [temp.array];
                
            	break;
            
            case filterType.Sub:
                actualData ~=  sub!(op,inequality,inverseOp)(scanline).join; 
            	break;
            
            case filterType.Up:
                scanline.each!(a => a.each!(b => temp ~= b));
                actualData ~= [(temp[] += actualData.back[]).map!(a => a.normalizePixelValue).array];

                break;
	    
            case filterType.Average:
                actualDataBack = actualData.back;
                auto up = actualDataBack.chunks(lengthPerPixel);
                auto current = scanline.chunks(lengthPerPixel);
                int[] upPixel = *cast(int[]*)&up;
            	scanline.popFront;            		
            	auto sc = scanline.join;
                up.front.each!((idx,n) =>temp ~= ((n/2) + current.front[0][idx]).normalizePixelValue);

                upPixel[lengthPerPixel .. $].each!((o,n)=>  
                                temp ~= (((temp[o] + n)/2) + sc[o]).normalizePixelValue);

                actualData ~= [temp];
                break;

            case filterType.Paeth:
                auto joined = scanline.join;

                actualData.back[0 .. lengthPerPixel]
                                .each!((idx,a) => temp ~= (a + joined[idx]).normalizePixelValue);
                
                actualData.back[lengthPerPixel .. $]
                              .each!((idx, a) => 
                              temp ~= (paethPredictor(temp[idx], a, actualData.back[idx]) 
                                    + joined[idx + lengthPerPixel])
                              .normalizePixelValue);
            
                actualData ~= [temp];
                break;

  	    default:
                break;
        }       
    }
    return actualData;
}
 

public int[][] parse(ref Header info, string filename){
    ubyte[] data = cast(ubyte[])filename.read;
    int idx       = 0;
    int sigSize   = 8;

    if (data.take(sigSize) != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        throw new Exception("Invalid PNG format.");
    
    int chunkLengthSize = 4;
    int chunkTypeSize   = 4;
    int chunkCrcSize    = 4;
    int chunkDataSize;
    string chunkType;
    int[][] actualData;
    ubyte[] uncIDAT;
    const string[] ancillaryChunks = ["tRNS","gAMA","cHRM","sRGB","iCCP","tEXt","zTXt",
                                      "iTXt","bKGD","pHYs","vpAg","sBIT","sPLT","hIST","tIME",
                                      "fRAc","gIFg","gIFt","gIFx","oFFs","pCAL","sCAL"];
    
    idx += sigSize;
    UnCompress uc = new UnCompress(HeaderFormat.deflate);
    while (idx >= 0){
        chunkDataSize = data[idx .. idx+chunkLengthSize].byteToInt;
        idx += chunkLengthSize;
        chunkType = data[idx .. idx+chunkTypeSize].byteToString;

        switch(chunkType){
            case "IHDR":
              int endIdx = chunkTypeSize + chunkDataSize + chunkCrcSize;
              info = data[idx .. idx + endIdx].readIHDR;
              idx += endIdx;
              break;
            
            case "IDAT":
                int endIdx = chunkDataSize + chunkCrcSize;
                ubyte[] idat = data[idx .. idx + endIdx].readIDAT;
                idx += chunkLengthSize + endIdx;

                if(info.colorType ==  colorType.grayscale || info.colorType ==  colorType.grayscaleA){
                    lengthPerPixel = info.width;
                    actualData ~= idat.chunks(lengthPerPixel).array.to!(int[][]);
                    break;
                }

                uncIDAT ~= cast(ubyte[])uc.uncompress(idat.dup);
                break;
          
            case "IEND": 
                idx = -1; // To end while() loop
                break;

            default:  // except for IHDR, IDAT, IEND
                if (!ancillaryChunks.canFind(chunkType))
                      throw new Exception("Invalid png format"); 
                //writeln(chunkType);
                idx += chunkTypeSize + chunkDataSize + chunkCrcSize;
        }
    }
    if(uncIDAT.length == 0 || info.colorType == colorType.grayscale || info.colorType == colorType.grayscaleA) 
        return actualData;
   
    uint numScanline = (uncIDAT.length / info.height).to!uint;
    auto chunks = uncIDAT.chunks(numScanline).array;
    ubyte[][] uncChunks = (*cast(ubyte[][]*)&chunks).array;
    actualData = inverseFiltering!("+","<256","-")(uncChunks);

    return actualData; 
}

