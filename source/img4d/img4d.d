module img4d.img4d;
import img4d_lib.decode,
       img4d_lib.encode,
       img4d_lib.filter,
       img4d_lib.color_space,
       img4d_lib.edge;

import std.stdio,
       std.array,
       std.bitmanip,
       std.conv,
       std.algorithm,
       std.range,
       std.math,
       std.range.primitives,
       std.algorithm.mutation,
       std.file : exists;

int lengthPerPixel;

enum filterType{
    None,
    Sub,
    Up,
    Average,
    Paeth
}

enum colorType{
    grayscale,
    trueColor = 2,
    indexColor,
    grayscaleA,
    trueColorA = 6,
}

struct Header {

    this(int width, int height, int bitDepth, int colorType,
        int compressionMethod, int filterMethod, int interlaceMethod, ubyte[] crc){
        
        _width              = width;
        _height             = height;
        _bitDepth           = bitDepth;
        _colorType          = colorType;
        _compressionMethod  = compressionMethod;
        _filterMethod       = filterMethod;
        _interlaceMethod    = interlaceMethod;
        _crc                = crc; 
    }
    
    @property{
        void width(int width){ _width = width;}
        void height(int height){ _height = height; }
        void bitDepth(int bitDepth){ _bitDepth = bitDepth; }
        void colorType(int colorType){ _colorType = colorType; }
        void compressionMethod (int compressionMethod){ _compressionMethod = compressionMethod; }
        void filterMethod(int filterMethod){ _filterMethod = filterMethod; }
        void interlaceMethod(int interlaceMethod){ _interlaceMethod = interlaceMethod; }
        void crc(ubyte[] crc){_crc = crc;}

        int width(){ return _width; }
        int height(){ return _height; }
        int bitDepth(){ return  _bitDepth; }
        int colorType(){ return  _colorType; }
        int compressionMethod (){ return  _compressionMethod; }
        int filterMethod(){ return  _filterMethod; }
        int interlaceMethod(){ return  _interlaceMethod; }
        ubyte[] crc(){ return  _crc; }
    }

    private:
        int   _width,
              _height,
              _bitDepth,
              _colorType,
              _compressionMethod,
              _filterMethod,
              _interlaceMethod;
        ubyte[] _crc;
}

auto decode(ref Header header, string filename){
    if(!exists(filename))
        throw new Exception("Not found the file.");
    return parse(header, filename);
}

ubyte[] encode(T)(Header header,  T[][] color){
    if(color == null) throw new Exception("null reference exception");
    ubyte[] data = header.makeIHDR ~ color.makeIDAT(header) ~ makeIEND;
    return data;
}

// Canny Edge Detection (Defective)
auto canny(T)(T[][] actualData, int tMin, int tMax){
    double[][] gaussian = [[0.0625, 0.125, 0.0625],
                          [0.125, 0.25, 0.125],
                          [0.0625, 0.125, 0.0625]];
    double[][] sobelX = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]];
    double[][] sobelY = [[-1, -2, -1], [0, 0, 0],[1, 2, 1]];

    auto G  = actualData.differential(gaussian);
    auto Gx = G.differential(sobelX);
    auto Gy = G.differential(sobelY);
    double[][]  Gr = minimallyInitializedArray!(double[][])(Gx.length, Gx[0].length);
    double[][]  Gth= minimallyInitializedArray!(double[][])(Gx.length, Gx[0].length);

    foreach(idx; 0 .. Gx.length){
        foreach(edx; 0 .. Gx[0].length){
            Gr[idx][edx]  = sqrt(Gx[idx][edx].pow(2)+Gy[idx][edx].pow(2));
            Gth[idx][edx] = ((atan2(Gy[idx][edx], Gx[idx][edx]) * 180) / PI); 
        }
    }

    auto approximateG = Gr.gradient(Gth);
    auto edge = approximateG.hysteresis(tMin, tMax);

    return edge;
}

auto rgbToGrayscale(T)(T[][][] color){ return color.toGrayscale; }

auto toBinary(T)(ref T[][] gray, T threshold=127){
    // Simple thresholding 

    T[][] bin;
    gray.each!(a =>bin ~=  a.map!(b => b < threshold ? 0 : 255).array);
    return bin;
}

auto toBinarizeElucidate(T)(T[][] array, string process="binary"){
    uint imageH = array.length;
    uint imageW = array[0].length;
    int vicinityH = 3;
    int vicinityW = 3;
    int h = vicinityH / 2;
    int w = vicinityW / 2;
    
    auto output = minimallyInitializedArray!(typeof(array))(imageH, imageW);
    output.each!(a=> fill(a,0));
    
    foreach(i; h .. imageH-h){
        foreach(j;  w .. imageW-w){
            if (process=="binary"){
                int t = 0;
                foreach(m; 0 .. vicinityH){
                    foreach(n; 0 .. vicinityW){      
                        t += array[i-h+m][j-w+n];
                    }
                }
                if((t/(vicinityH*vicinityW)) < array[i][j]) output[i][j] = 255;
            }              
            else if(process == "median"){
                T[] t;
                foreach(m; 0 .. vicinityH){
                    foreach(n; 0 .. vicinityW){      
                        t ~= array[i-h+m][j-w+n].to!T;
                    }
                }    
                output[i][j] = t.sort[4];
            }  
        }
    }
    return output;
}

auto differ(T)(ref T[][] origin, ref T[][] target){
    T[][] diff;
    origin.each!((idx,a) => diff ~=  (target[idx][] -= a[]).map!(b => abs(b)).array);

    return diff;
}

auto mask(T)(ref T[][][] colorTarget, ref T[][] gray){
    T[][] masked;
    masked.length = gray.length;
    gray.each!((idx,a)=> a.each!((edx,b) => masked[idx] ~= b==255 ? colorTarget[idx][edx] : [0, 0, 0]));
  
    return masked;
}