# img4d   [![Status](https://travis-ci.org/DYGV/img4d.svg?branch=master)](https://travis-ci.org/DYGV/img4d)
## What's this ?  
PNG images Decoder in D language.  
It's defective implemention and I cannot guarantee the operation.  
Please see current status on [commit page](https://github.com/DYGV/img4d/commits/master)  
# Package  
 [img4d_lib.decode](https://github.com/DYGV/img4d/blob/master/README.md#img4d_libdecode)  
 [img4d_lib.encode](https://github.com/DYGV/img4d/blob/master/README.md#img4d_libencode)  
 [img4d_lib.color_space](https://github.com/DYGV/img4d/blob/master/README.md#img4d_libcolor_space)  
 [img4d_lib.edge](https://github.com/DYGV/img4d/blob/master/README.md#img4d_libedge)  
  
## img4d_lib.decode  
-  **PNG_Header read_IHDR(ubyte[] header)**  
Set PNG_Header struct and Return its struct  
   - ***Params:***  
ubyte[] header: Header byte-data  
  
- **int byte_to_int(T)(T[] data)**  
Return ChunkData-length(Convert byte array to int)   
  
- **string byte_to_string(T)(T[] data)**  
Return Chunk Type(Convert byte array to string)   
  
- **ubyte[] read_idat(ubyte[] data)**  
Calculate CRC and Return IDAT Chunk-Data  
   - ***Params:***  
ubyte[] data : IDAT array expect for Chunk-Data-Size  
  
- **void crc_check(ubyte[] crc, ubyte[] chunk)**  
The function of CRC calculation  
  - ***Params***  
ubyte[] crc : The CRC code at the end of the chunk  
ubyte[] chunk : Byte array to be CRC calculated  
  
- **int PaethPredictor(int left, int upper, int upper_left)**  
Calculate and Return Paeth-Predictor  
- **auto normalize_pixel_value(T)(T value)**  
Return the value which are subtracted 256 if it exceeds 256  
- **int[][] inverse_filtering(string op, string inequality, string inv_op)(ubyte[][] data)**  
- **int[][] parse(ref PNG_Header info, string filename)**  
## img4d_lib.encode  
- **ubyte[] make_IHDR(in PNG_Header info)**  
- **ubyte[] make_IDAT(T)(T[][] actual_data, in PNG_Header info)**  
- **ubyte[] make_ancillary()**  
Not implemented  
- **ubyte[] make_IEND()**  
- **auto make_crc(in ubyte[] data)**  
## img4d_lib.filter  
- **auto calculate(string op, T)(T lhs, T rhs)**  
- **auto Sub(string op, string inequality, string inv_op, T)(T[][] sc_data)**  
- **auto Up()**  
Not implemented  
- **auto Ave()**  
Not implemented  
- **auto Paeth()**
Not implemented  
## img4d_lib.color_space  
- **double[][] to_grayscale(T)(ref T[][][] color)**  
## img4d_lib.edge  
- **auto differential(T)(T[][] array, T[][] filter)**  
- **auto gradient(T)(T[][] Gr, T[][] Gth)**  
- **auto hysteresis(T)(T[][] src, int t_min, int t_max)**  

