import img4d;
import std.stdio,
       std.range,
       std.algorithm.iteration;
int main(){
    PNG_Header before_encode;
    int[][][] actual_data;

    // start decode
    auto parsed_data = decode(before_encode, "../png_img/lena.png");
    if(parsed_data.length != 0) 
    parsed_data.each!(n  => actual_data ~= n.chunks(length_per_pixel).array);

    writefln("Width  %8d\nHeight  %7d",
          before_encode.width,
          before_encode.height);
    writefln("Bit Depth  %4d\nColor Type  %3d\n",
          before_encode.bit_depth, 
          before_encode.color_type, 
          before_encode.compression_method);

    // start encode
    ubyte[] encoded_data = before_encode.encode;
    auto file = File("../png_img/encoded_lena.png","w");
    file.rawWrite(encoded_data);

    PNG_Header after_encode;
    
    //read encoded file
    auto encoded_data_to_decode = decode(after_encode, "../png_img/encoded_lena.png");
 writefln("Width  %8d\nHeight  %7d",
          after_encode.width,
          after_encode.height);
    writefln("Bit Depth  %4d\nColor Type  %3d",
          after_encode.bit_depth, 
          after_encode.color_type, 
          after_encode.compression_method);

    

    // auto rgb_file = File("../png_img/rgb_lena.txt","w");
    // rgb_file.writeln(actual_data);

  /*
     covert to grayscale
   */
    auto gray = rgb_to_grayscale(actual_data);
    // auto gray_file = File("../png_img/gray_lena.txt","w");
    // gray_file.writeln(gray);

  /*
     convert to binary image by simple thresholding
   */
    auto bin = to_binary(gray);
    // auto bin_file = File("../png_img/bins_simple_lena.txt","w");
    // bin_file.writeln(bin);

  /*
     convert ot binary image by adaptive threshoding
   */
    auto bin_adaptive = to_binarize_elucidate(gray);
    // auto bin_adaptive_file = File("../png_img/bin_adaptive_lena.txt","w");
    // bin_adaptive.each!(a => bin_adaptive_file.writeln(a));
  

    auto median = to_binarize_elucidate(bin_adaptive, "median");
    //auto median_filter_file = File("../png_img/median_filter_lena.txt","w");
    //median.each!(a => median_filter_file.writeln(a));
    
    return 0;
}


