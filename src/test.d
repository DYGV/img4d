import img4d;
import std.stdio,
       std.range,
       std.algorithm.iteration;
int main(){
    int[][][] actual_data;
    auto parsed_data = parse("../png_img/lena.png");
    if(parsed_data.length != 0)
        parsed_data.each!(n  => actual_data ~= n.chunks(length_per_pixel).array);
    auto rgb_file = File("../png_img/rgb_lena.txt","w");
    rgb_file.writeln(actual_data);

  /*
     covert to grayscale
   */
    auto gray = to_grayscale(actual_data);
    auto gray_file = File("../png_img/gray_lena.txt","w");
    gray_file.writeln(gray);

  /*
     convert to binary image
   */
    auto bin = to_binary(gray);
    auto bin_file = File("../png_img/bin_lena.txt","w");
    bin_file.writeln(bin);

  /*
     convert ot binary image by adaptive threshoding
   */
    auto bin_adaptive = to_adaptive_binary(gray);
    auto bin_adaptive_file = File("../png_img/bin_adaptive_lena.txt","w");
    bin_adaptive_file.writeln(bin_adaptive);

    return 0;
}

