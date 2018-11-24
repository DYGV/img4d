import img4d,
       img4d_lib.edge;
import std.stdio,
       std.range,
       std.algorithm.iteration,
       std.process,
       std.array,
       std.algorithm,
       std.range,
       std.math;

/*
 *
 *
 *
 *
 *        Not available probably
 *
 *
 *
 *
 */



int main(){
    PNG_Header info;
    int[][][] actual_data;
    auto parsed_data = info.decode("../png_img/lena.png");
    if(parsed_data.length == 0) {return 0;}

    double[][] gaussian = [[0.0625, 0.125, 0.0625],
                          [0.125, 0.25, 0.125],
                          [0.0625, 0.125, 0.0625]];
    double[][] sobel_x = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]];
    double[][] sobel_y = [[-1, -2, -1], [0, 0, 0],[1, 2, 1]];

    parsed_data.each!(n  => actual_data ~= n.chunks(length_per_pixel).array);
    auto gray = rgb_to_grayscale(actual_data);

    auto G  = differential(gray, gaussian);
    auto Gx = differential(G, sobel_x);
    auto Gy = differential(G, sobel_y);
    double[][]  Gr = minimallyInitializedArray!(double[][])(Gx.length, Gx[0].length);
    double[][]  Gth= minimallyInitializedArray!(double[][])(Gx.length, Gx[0].length);

    foreach(idx; 0 .. Gx.length){
        foreach(edx; 0 .. Gx[0].length){
         Gr[idx][edx]  = sqrt(Gx[idx][edx].pow(2)+Gy[idx][edx].pow(2));
         Gth[idx][edx] = ((atan2(Gy[idx][edx], Gx[idx][edx]) * 180) / PI); 
        }
    }

    auto approximate_G = gradient(Gr, Gth);
    auto edge = hysteresis(approximate_G, 30, 150);
    auto edge_file = File("../png_img/edge_lena.txt","w");
    edge.each!(a => edge_file.writeln(a));
    edge_file.flush();

    executeShell("cd ../png_img && python generate_img.py");

    return 0;
}
