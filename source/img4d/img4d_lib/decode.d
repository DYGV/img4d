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

Header readIHDR(ubyte[] header){
    if(header.length != 21) throw new Exception("invalid header format");
    ubyte[] chunk = header[0 .. 17];  // Chunk Type + Chunk Data 
    Header IHDR = Header(header[4 .. 8].byteToInt, // width
                        header[8 .. 12].byteToInt,  // height
                        header[12],  // bitDepth
			header[13],  // colorType
                        header[14],  // compressionMethod
			header[15],  // filterMethod
                        header[16],  // interlaceMethod
			header[17 .. 21]  // crc
			);

    switch(IHDR.colorType) with(colorTypes){
        case grayscale:
            lengthPerPixel = IHDR.width;
            break;
        case trueColor:
            lengthPerPixel = 3;
            break;
        case indexColor:
            lengthPerPixel = 3;
            break;
        case grayscaleA:
            lengthPerPixel = IHDR.width * 2;
            break;
        case trueColorA:
            lengthPerPixel = 4;
            break;
        default:
            break;
    }

    crcCheck(IHDR.crc, chunk);
    return IHDR;
}



  /**
   *  convert from the given endianness 
   *  to the native endianness
   */
int byteToInt(ubyte[] data){ return data.peek!int(); }


  /**
   *  Cast array to string
   */
string byteToString(T)(T[] data){ return cast(string)data; }


ubyte[] readIDAT(ubyte[] data){
    version(none){
        ubyte[] dataCrc = data[0 .. $-4];
        ubyte[] crc = data[$-4 .. $];
        crcCheck(crc, dataCrc);
    }
    return data[4 .. $-4];
}



bool crcCheck(ubyte[] crc, in ubyte[] chunk){
    reverse(crc[]);
    if (crc != chunk.crc32Of){
          throw new Exception("invalid");
    }
    return true;
}



int paethPredictor(int left, int upper, int upperLeft){
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



auto normalizePixelValue(T)(T value){ return value < 256 ? value : value - 256; }


ubyte[][] inverseFiltering(ref ubyte[][] data){
    ubyte[][][] rgb;
    ubyte[][][] compData;
    ubyte[] filters;
    ubyte[][] actualData;
    data.each!(sc => filters ~= sc.front);
    data.each!(sc => rgb ~= [sc.remove(0).chunks(lengthPerPixel).array]);

    foreach(idx, scanline; rgb){
        ubyte[] temp;
        ubyte[] predictor;
        ubyte[] actualDataBack;

        switch(filters[idx]) with(filterTypes){
            case None:
                temp = scanline[0];
            	actualData ~= [temp.array];
                
            	break;
            
            case Sub:
                actualData ~=  [scanline.inverseSub.join].to!(ubyte[][]); 
            	break;
            
            case Up:
                scanline.each!(a => a.each!(b => temp ~= b));
                actualData ~= [(temp[] += actualData.back[]).map!(a => a.normalizePixelValue).array].to!(ubyte[][]);

                break;
	    
            case Average:
                actualDataBack = actualData.back;
                auto up = actualDataBack.chunks(lengthPerPixel);
                auto current = scanline.chunks(lengthPerPixel);
                ubyte[] upPixel = *cast(ubyte[]*)&up;
            	scanline.popFront;            		
            	auto sc = scanline.join;
                up.front.each!((idx,n) =>temp ~= [((n/2) + current.front[0][idx]).normalizePixelValue].to!(ubyte[]));

                upPixel[lengthPerPixel .. $].each!((o,n)=>  
                                temp ~= [(((temp[o] + n)/2) + sc[o]).normalizePixelValue].to!(ubyte[]));

                actualData ~= [temp];
                break;

            case Paeth:
                auto joined = scanline.join;

                actualData.back[0 .. lengthPerPixel]
                                .each!((idx,a) => temp ~= [(a + joined[idx]).normalizePixelValue].to!(ubyte[]));
                
                actualData.back[lengthPerPixel .. $]
                              .each!((idx, a) => 
                              temp ~= [(paethPredictor(temp[idx], a, actualData.back[idx]) 
                                    + joined[idx + lengthPerPixel])
                              .normalizePixelValue].to!(ubyte[]));
            
                actualData ~= [temp];
                break;

  	    default:
                break;
        }       
    }
    return actualData;
}



ubyte[][] parse(ref Header header, string filename){
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
    ubyte[][] actualData;
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
                header = data[idx .. idx + endIdx].readIHDR;
                idx += endIdx;
                break;
            
            case "IDAT":
                int endIdx = chunkDataSize + chunkCrcSize;
                ubyte[] idat = data[idx .. idx + endIdx].readIDAT;
                idx += chunkLengthSize + endIdx;
                uncIDAT ~= cast(ubyte[])uc.uncompress(idat.dup);
                break;
          
            case "IEND": 
                idx = -1; // To end while() loop
                break;

            default:  // except for IHDR, IDAT, IEND
                if (!ancillaryChunks.canFind(chunkType))
                      throw new Exception("Invalid png format"); 
                //chunkType.writeln;
                idx += chunkTypeSize + chunkDataSize + chunkCrcSize;
        }
    }
    uint numScanline = (uncIDAT.length / header.height).to!uint;
    auto chunks = uncIDAT.chunks(numScanline).array;
    ubyte[][] uncChunks = (*cast(ubyte[][]*)&chunks).array;
    with(header){
        with(colorTypes){ 
            if(uncIDAT.empty || colorType == grayscale || colorType == grayscaleA) {
                return uncChunks;
            }
        }
    }

    actualData = uncChunks.inverseFiltering;
    return actualData; 
}
