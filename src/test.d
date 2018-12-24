import img4d;
import std.stdio,
       std.range,
       std.algorithm.iteration,
       std.process;

int main(){
    Header beforeEncode;
    int[][][] actualData;

    // start decode
    auto parsedData = beforeEncode.decode("../png_img/lena.png");
    if(parsedData.length == 0) {return 0;}
    parsedData.each!(n  => actualData ~= n.chunks(lengthPerPixel).array);

    writefln("Width  %8d\nHeight  %7d",
          beforeEncode.width,
          beforeEncode.height);
    writefln("Bit Depth  %4d\nColor Type  %3d\n",
          beforeEncode.bitDepth, 
          beforeEncode.colorType);
    auto gray = rgbToGrayscale(actualData);
    beforeEncode.colorType = colorType.grayscale;

    /*  Canny Edge Detection (Defective State) 
    auto gray = rgbToGrayscale(actualData);
    auto edge = canny(gray,80,150);
    auto edgeFile = File("../png_img/edge_lena.txt","w");
    edge.each!(a => edgeFile.writeln(a));
    edgeFile.flush();
    executeShell("cd ../png_img && python generate_img.py");
    */
    
    // start encode
    ubyte[] encodedData = beforeEncode.encode(gray);
    auto file = File("../png_img/encoded_lena.png","w");
    file.rawWrite(encodedData);
    file.flush(); 
    //read encoded file
    Header afterEncode;

    auto encodedDataToDecode = afterEncode.decode("../png_img/encoded_lena.png");
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

    // auto rgbFile = File("../png_img/rgb_lena.txt","w");
    // rgbFile.writeln(actual_data);

  /*
     covert to grayscale
   */
    // auto gray = rgbToGrayscale(actual_data);
    // auto grayFile = File("../png_img/gray_lena.txt","w");
    // grayFile.writeln(gray);

  /*
     convert to binary image by simple thresholding
   */
    // auto bin = toBinary(gray);
    // auto binFile = File("../png_img/bins_simple_lena.txt","w");
    // binFile.writeln(bin);

  /*
     convert ot binary image by adaptive threshoding
   */
    // auto binAdaptive = toBinarizeElucidate(gray);
    // auto binAdaptiveFile = File("../png_img/binAdaptive_lena.txt","w");
    // binAdaptive.each!(a => binAdaptiveFile.writeln(a));
  

    // auto median = toBinarizeElucidate(binAdaptive, "median");
    // auto medianFilterFile = File("../png_img/median_filter_lena.txt","w");
    // median.each!(a => medianFilterFile.writeln(a));
    
    return 0;
}


