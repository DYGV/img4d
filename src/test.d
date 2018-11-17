import img4d;
import std.stdio,
       std.range,
       std.algorithm.iteration,
       std.process;

int main(){
    PNG_Header before_encode;
    int[][][] actual_data;

    // start decode
    auto parsed_data = before_encode.decode("../png_img/lena.png");
    if(parsed_data.length == 0) {return 0;}
    parsed_data.each!(n  => actual_data ~= n.chunks(length_per_pixel).array);

    writefln("Width  %8d\nHeight  %7d",
          before_encode.width,
          before_encode.height);
    writefln("Bit Depth  %4d\nColor Type  %3d\n",
          before_encode.bit_depth, 
          before_encode.color_type);

    // start encode
    ubyte[] encoded_data = before_encode.encode(parsed_data);
    auto file = File("../png_img/encoded_lena.png","w");
    file.rawWrite(encoded_data);
    file.flush(); 
    //read encoded file
    PNG_Header after_encode;

    auto encoded_data_to_decode = after_encode.decode("../png_img/encoded_lena.png");
    writefln("Width  %8d\nHeight  %7d",
          after_encode.width,
          after_encode.height);
    writefln("Bit Depth  %4d\nColor Type  %3d\n",
          after_encode.bit_depth, 
          after_encode.color_type);

    executeShell("cd ../png_img && composite -compose difference lena.png encoded_lena.png diff.png");
    auto diff =  executeShell("cd ../png_img && identify -format \"%[mean]\" diff.png").output;
    if(diff != "0\n"){
        "something is wrong (It doesn't match the original image)".writeln;
        diff.writeln;
    }

    // auto rgb_file = File("../png_img/rgb_lena.txt","w");
    // rgb_file.writeln(actual_data);

  /*
     covert to grayscale
   */
    // auto gray = rgb_to_grayscale(actual_data);
    // auto gray_file = File("../png_img/gray_lena.txt","w");
    // gray_file.writeln(gray);

  /*
     convert to binary image by simple thresholding
   */
    // auto bin = to_binary(gray);
    // auto bin_file = File("../png_img/bins_simple_lena.txt","w");
    // bin_file.writeln(bin);

  /*
     convert ot binary image by adaptive threshoding
   */
    // auto bin_adaptive = to_binarize_elucidate(gray);
    // auto bin_adaptive_file = File("../png_img/bin_adaptive_lena.txt","w");
    // bin_adaptive.each!(a => bin_adaptive_file.writeln(a));
  

    // auto median = to_binarize_elucidate(bin_adaptive, "median");
    // auto median_filter_file = File("../png_img/median_filter_lena.txt","w");
    // median.each!(a => median_filter_file.writeln(a));
    
    return 0;
}


