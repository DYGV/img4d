module img4d_lib.filter;
import std.stdio,
       std.array,
       std.conv,
       std.algorithm,
       std.range;
import std.range.primitives;
import std.algorithm.mutation;

auto calculate(string op, T)(T lhs, T rhs)
{
    return mixin("lhs " ~ op ~ " rhs");
}

public auto sub(string op, string inequality, string inverseOp, T)(T[][] scanline){
    return [scanline.front.walkLength.iota
        .map!(i => transversal(scanline, i).chain
            .cumulativeFold!((a,b) =>
                mixin("calculate!op(a,b)"~inequality) 
                ? mixin("calculate!op(a,b)")
                : mixin("calculate!op(a,b)" ~inverseOp~ "256")))]
                .join.transposed;
}

public auto up(){}

public auto ave(){}

public auto paeth(){}

unittest{
    assert(calculate!"+"(5, 10) == 15);
    assert(calculate!"-"(5, 10) == -5);

    int[][] filtered = [[1, 1, 255], [255, 2, 3], [3, 2, 1]];
    int[][] before   = [[1, 1, 255], [0, 3, 2], [3, 5, 3]];
        
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
    sub!("+","< 256","-")(filtered).each!((idx,a) =>
        assert(a.equal(before[idx])));
    "unittest of Sub filter was passed".writeln;
}