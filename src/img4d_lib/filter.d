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

public auto Sub(string op, string inequality, string inv_op,T)(T[][] sc_data){
    return [sc_data.front.walkLength.iota
        .map!(i => transversal(sc_data, i).chain
            .cumulativeFold!((a,b) =>
                mixin("calculate!op(a,b)"~inequality) 
                ? mixin("calculate!op(a,b)")
                : mixin("calculate!op(a,b)" ~inv_op~ "256")))]
                .join.transposed;
}

public auto Up(){}

public auto Ave(){}

public auto Paeth(){}

unittest{
    assert(calculate!"+"(5, 10) == 15);
    assert(calculate!"-"(5, 10) == -5);

    int[][] test_array = [[1, 1, 1], [3, 2, 1], [1, 2, 3]];
    int[][] filtered_array = [[1, 1, 1], [254, 255, 0], [253, 253, 253]];
    
    Sub!("-",">=0","+")(test_array).each!((idx,a) => assert(equal(a.array,filtered_array[idx])));
    
    "unittest of Sub filter was passed".writeln;
}
