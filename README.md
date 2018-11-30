# img4d   [![Status](https://travis-ci.org/DYGV/img4d.svg?branch=master)](https://travis-ci.org/DYGV/img4d)
## What's this ?  
PNG images Decoder in D language.  
It's defective implemention and I cannot guarantee the operation.  
Please see current status on [commit page](https://github.com/DYGV/img4d/commits/master)  
# Package  
## img4d_lib.decode  
-  **PNG_Header read_IHDR(ubyte[] header)**  
Set PNG_Header struct and Return its struct  
   - ***Params:***  
ubyte[] header: Header byte-data  
  
- **int read_data_chunk_len(ubyte[] data)**  
Return ChunkData-length(Convert byte array to int)   
  
- **string read_chunk_type(ubyte[] data)**  
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
## img4d_lib.filter  
## img4d_lib.color_space  
## img4d_lib.edge  

