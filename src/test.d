import PNG_Parse;
import std.stdio,
       std.range,
       std.algorithm.iteration;
int main(){
    int[][][] actual_data;
    auto parsed_data = parse("../png_img/lena.png");
    parsed_data.each!(n  => actual_data ~= n.chunks(length_per_pixel).array);
    return 0;
}

