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
