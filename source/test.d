import img4d;
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
       std.string,
       std.range.primitives,
       std.algorithm.mutation,
       std.file,
       std.algorithm.iteration;



/* readIHDR */
unittest{
    ubyte[21] headers =['I', 'H', 'D', 'R', // chunk type
                        0, 0, 0, 5,         // height
                        0, 0, 0, 5,         // width
                        8,                  // bitDepth
                        2,                  // colorType
                        0,                  // compressionMethod
                        0,                  // filterMethod
                        0,                  // interlaceMethod
                        2, 13, 177, 178];   // calculated crc

    Header hdr = headers.readIHDR;
    
    assert(hdr.height             == headers[4 .. 8].byteToInt);
    assert(hdr.width              == headers[8 .. 12].byteToInt);
    assert(hdr.bitDepth           == headers[12]);
    assert(hdr.colorType          == headers[13]);
    assert(hdr.compressionMethod  == headers[14]);
    assert(hdr.filterMethod       == headers[15]);
    assert(hdr.interlaceMethod    == headers[16]);
}



/* byteToInt */
unittest{
    ubyte[] ubyteArray = [0,0,0,5];
    assert(ubyteArray.byteToInt == 5);
}



/* byteToString */
unittest{
    ubyte[] hello = ['H', 'E', 'L', 'L', 'O'];
    assert(hello.byteToString == "HELLO");
}



/* crcCheck */
unittest{
    ubyte[] crc = [2, 13, 177, 178];
    ubyte[] data = [0x49, 0x48, 0x44, 0x52, 0x0, 0x0, 0x0, 0x5, 
                  0x0, 0x0, 0x0, 0x5, 0x8, 0x2, 0x0, 0x0, 0x0];
    assert(crc.crcCheck(data));
}



/* normalizePixelValue */
unittest{
    assert(100.normalizePixelValue == 100); // 100 < 256 => 100 
    assert(300.normalizePixelValue == 44);  // 300 > 256 => 300 - 256 = 44
}



/* sumScanline */
unittest{
    ubyte[][] src = [[1, 2, 3], [4, 5, 6]];
    // [1+2+3. 4+5+6] == [6, 15]
    ubyte[] sum   = [6, 15];
    assert(src.sumScanline.equal(sum));
}



/* chooseFilterType grayscale */ 
unittest{
    ubyte[21] headers =['I', 'H', 'D', 'R', // chunk type
                        0, 0, 0, 5,         // height
                        0, 0, 0, 5,         // width
                        8,                  // bitDepth
                        0,                  // colorType
                        0,                  // compressionMethod
                        0,                  // filterMethod
                        0,                  // interlaceMethod
                        168, 4, 121, 57];   // calculated crc

    Header hdr = headers.readIHDR;
    ubyte[][]  data = [[0, 0, 0, 0, 0],
                      [1, 2, 3, 4, 5],
                      [0, 100, 0, 100, 0],
                      [0, 100, 0, 100, 0],
                      [1, 0, 1, 0, 1]];
    Pixel pix = Pixel(data);
    assert(hdr.chooseFilterType(pix) == 
            [[0, 0, 0, 0, 0, 0], 
            [1, 1, 1, 1, 1, 1], 
            [0, 0, 100, 0, 100, 0], 
            [2, 0, 0, 0, 0, 0], 
            [0, 1, 0, 1, 0, 1]]);
}



/* chooseFilterType color */ 
unittest{
    ubyte[] headers =['I', 'H', 'D', 'R', // chunk type
                        0, 0, 0, 5,         // height
                        0, 0, 0, 2,         // width
                        8,                  // bitDepth
                        2,                  // colorType
                        0,                  // compressionMethod
                        0,                  // filterMethod
                        0,                  // interlaceMethod
                        31,8,129,10];
    Header hdr = headers.readIHDR;
    ubyte[][]  data = [[0, 0, 0, 0, 0, 0],
                      [1, 2, 3, 4, 5, 6],
                      [0, 100, 0, 100, 0, 100],
                      [0, 100, 0, 100, 0,100],
                      [1, 0, 1, 0, 1,0]];
    Pixel pix = Pixel(data, data, data);
    assert(hdr.chooseFilterType(pix) == [[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        [0, 0, 0, 0, 100, 100, 100, 0, 0, 0, 100, 100, 100, 0, 0, 0, 100, 100, 100],
        [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0]]);

}



/* joinVertical */
unittest{
    ubyte[][] horizontal  = [[1, 2, 3],[4, 5, 6],[7, 8, 9]];
    ubyte[][] vertical    = [ [1,4,7],
                              [2,5,8],
                              [3,6,9] ];
    assert(horizontal.joinVertical.equal(vertical));
}



/* neighborDifference */
unittest{
    ubyte[][] beforeCalculateDiff = [[1, 2, 3],[9, 3, 0]];
    assert(beforeCalculateDiff.map!(a => a.slide(2).array)
      .equal([[[1, 2], [2, 3]], [[9, 3], [3, 0]]]));
    
    // front - back < 0 => abs(front - back)
    // front - back > 0 => 256 - (front - back)
    ubyte[][] diff  = [[1, 1, 1],
                      [9, 250, 253]];
    assert(beforeCalculateDiff.neighborDifference.equal(diff));
}



/* inverseSub */ 
unittest{
    ubyte[][] filtered  = [[1, 1, 255], [255, 2, 3], [3, 2, 1]];
    ubyte[][] unFilter  = [[1, 1, 255], [0, 3, 2], [3, 5, 3]];
        
    /*
       sub filter
       the first pixel is intact  =>                1,1,1

         1 + 255 = 256 >= 256     =>  256 - 256 = 0  => 0
         1 +   2 =   3 <  256     =>                    3
       255 +   3 = 258 >  256     =>  258 - 256 = 2  => 2

         0 +   3 =   3 <  256     =>                    3
         3 +   2 =   5 <  256     =>                    5
         2 +   1 =   3 <  256     =>                    3
     */
    filtered.inverseSub.each!((idx,a) =>
        assert(a.equal(unFilter[idx])));
}



/* sub */
unittest{
    ubyte[][] beforeCalculateSub = [[1, 2, 3],[9, 3, 0]];
    ubyte[][] subFiltered = [[1, 1, 1],[9, 250, 253]];
    assert(beforeCalculateSub.sub.equal(subFiltered));
}



/* up */
unittest{
    ubyte[][] beforeCalculateUp = [[1, 2, 3], [1, 5, 2]];
    // joinVertical => [[1, 1],[2, 5],[3, 2]]
    // neighborDifference
    // =>
    // front - back < 0 => abs(front - back)
    // front - back > 0 => 256 - (front - back)

    ubyte[][] upFiltered = [[1, 2, 3],[0, 3, 255]];
    assert(beforeCalculateUp.up.equal(upFiltered));

}



/* parse */
unittest{
    Header hdr;

    ubyte[][] colorPix = hdr.parse("png_img/lena.png");
    string origin = readText("png_img/rgb_lena.txt");

    assert(origin ==  colorPix.join.map!(a => a.to!(string)).join);
}



/* decode */
unittest{
    Header hdr;

    Pixel colorPix = hdr.load("png_img/lena.png");
    string origin = readText("png_img/rgb_lena.txt");

    assert(origin ==  colorPix.Pixel.join.map!(a => a.to!(string)).join);
}



/* makeIEND */
unittest{
    assert(makeIEND == [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);

}



/* makeCrc */
unittest{
    ubyte[] data = [73, 69, 78, 68];
    assert(data.makeCrc == [174, 66, 96, 130]);
}
