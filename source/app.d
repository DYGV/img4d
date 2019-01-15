import img4d;
import std.stdio,
       std.range,
       std.algorithm.iteration,
       std.process,
       img4d_lib.filter;

int main(){
    Header beforeEncode;
    ubyte[][][] actualData;

    // start decode
    Pixel colorPix = beforeEncode.load("png_img/lena.png");
    if(colorPix.Pixel.length == 0) { return 0; }
    colorPix.Pixel.each!(n  => actualData ~= n.chunks(lengthPerPixel).array);

    writefln("Width  %8d\nHeight  %7d",
          beforeEncode.width,
          beforeEncode.height);
    writefln("Bit Depth  %4d\nColor Type  %3d\n",
          beforeEncode.bitDepth, 
          beforeEncode.colorType);
   
    Pixel grayPix = beforeEncode.rgbToGrayscale(actualData, true);
    beforeEncode.colorType = colorTypes.grayscale;
 
    /*  Canny Edge Detection (Defective State) 
    auto gray = rgbToGrayscale(actualData);
    auto edge = canny(gray,80,150);
    auto edgeFile = File("../png_img/edge_lena.txt","w");
    edge.each!(a => edgeFile.writeln(a));
    edgeFile.flush();
    executeShell("cd ../png_img && python generate_img.py");
    */
    
    // start encode
    bool encodedData = beforeEncode.save(grayPix, "png_img/encoded_lena.png");
   
    //read encoded file
    Header afterEncode;

    auto encodedDataToDecode = afterEncode.load("png_img/encoded_lena.png");
    writefln("Width  %8d\nHeight  %7d",
          afterEncode.width,
          afterEncode.height);
    writefln("Bit Depth  %4d\nColor Type  %3d\n",
          afterEncode.bitDepth, 
          afterEncode.colorType);
    
    // Verification (compare with original image)
    version(none){
        executeShell("cd ../png_img && composite -compose difference lena.png encoded_lena.png diff.png");
        auto diff =  executeShell("cd ../png_img && identify -format \"%[mean]\" diff.png").output;
        if(diff != "0\n"){
            "something is wrong (It doesn't match the original image)".writeln;
            diff.writeln;
        }
    }

    return 0;
}


