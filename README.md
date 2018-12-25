# img4d   [![Status](https://travis-ci.org/DYGV/img4d.svg?branch=master)](https://travis-ci.org/DYGV/img4d)  
PNG images Decoder/Encoder in D language.  
**It's defective implemention and I cannot guarantee the operation**.  
Please see current status on [commit page](https://github.com/DYGV/img4d/commits/master)  
# Examples  
## decode, convert to grayscale and encode
```D
import img4d;
import std.stdio,
       std.range,
       std.algorithm.iteration;

int main(){
    Header hdr;
    int[][][] actualData;

    // start decode
    auto parsedData = hdr.decode("../png_img/lena.png");
    if(parsedData.length == 0) {return 0;}
    parsedData.each!(n  => actualData ~= n.chunks(lengthPerPixel).array);  
    
    // convert to grayscale
    auto gray = rgbToGrayscale(actualData);
    hdr.colorType = colorType.grayscale;

    
    // start encode
    ubyte[] encodedData = hdr.encode(gray);
    auto file = File("../png_img/encoded_lena.png","w");
    file.rawWrite(encodedData);
    file.flush(); 
```    
# Package  
 [img4d_lib.decode](https://github.com/DYGV/img4d/blob/master/README.md#img4d_libdecode)  
 [img4d_lib.encode](https://github.com/DYGV/img4d/blob/master/README.md#img4d_libencode)  
 [img4d_lib.color_space](https://github.com/DYGV/img4d/blob/master/README.md#img4d_libcolor_space)  
 [img4d_lib.edge](https://github.com/DYGV/img4d/blob/master/README.md#img4d_libedge)  
  
## img4d_lib.decode  
-  **Header readIHDR(ubyte[] header)**  
Set Header struct and Return its struct  
   - ***Params:***  
ubyte[] header: Header byte-data  
  
- **int byteToInt(T)(T[] data)**  
Return ChunkData-length(Convert byte array to int)   
  
- **string byteToString(T)(T[] data)**  
Return Chunk Type(Convert byte array to string)   
  
- **ubyte[] readIDAT(ubyte[] data)**  
Calculate CRC and Return IDAT Chunk-Data  
   - ***Params:***  
ubyte[] data : IDAT array expect for Chunk-Data-Size  
  
- **void crcCheck(ubyte[] crc, in ubyte[] chunk)**  
The function of CRC calculation  
  - ***Params***  
ubyte[] crc : The CRC code at the end of the chunk  
ubyte[] chunk : Byte array to be CRC calculated  
  
- **int paethPredictor(int left, int upper, int upperLeft)**  
Calculate and Return Paeth-Predictor  
- **auto normalizePixelValue(T)(T value)**  
Return the value which are subtracted 256 if it exceeds 256  
- **int[][] inverseFiltering(string op, string inequality, string inverseOp)(ubyte[][] data)**  
- **int[][] parse(ref Header info, string filename)**  
## img4d_lib.encode  
- **ubyte[] makeIHDR(in Header info)**  
Return IHDR which required for encoding  
   - ***Params:***  
Header info : arranged Header  
- **ubyte[] makeIDAT(T)(T[][] actualData, in Header info)**  
Return IDAT which required for encoding  
   - ***Params:***  
T[][] actualData : IDAT chunk data  
Header info   : arranged Header  
- **ubyte[] makeAncillary()**  
Not implemented  
- **ubyte[] makeIEND()**  
Return IEND which required for encoding  
- **auto makeCrc(in ubyte[] data)**  
Calculate and Return CRC value  
## img4d_lib.filter  
- **auto calculate(string op, T)(T lhs, T rhs)**  
Calculate and Return using template arguments and mixin  
- **auto sub(string op, string inequality, string inverseOp, T)(T[][] scanline)**  
Calculate and Return Sub filter(Difference from left pixel)  
- **auto up()**  
Not implemented  
- **auto ave()**  
Not implemented  
- **auto paeth()**
Not implemented  
## img4d_lib.color_space  
- **double[][] toGrayscale(T)(ref T[][][] color)**  
Convert to grayscale by weighting  
## img4d_lib.edge  
- **auto differential(T)(T[][] array, T[][] filter)**  
- **auto gradient(T)(T[][] Gr, T[][] Gth)**  
- **auto hysteresis(T)(T[][] src, int t_min, int t_max)**  

