module img4d_lib.dft;

import std.stdio, std.array, std.conv, std.range, std.algorithm, std.math, std.complex;
import std.parallelism : parallel;

Complex!(double)[] dft(Complex!(double)[] data, int num)
{
	Complex!(double)[] dft_arr;
	dft_arr.length = num;
	double pi = PI.to!double;

	for (int i = 0; i < num; i++)
	{
		dft_arr[i] = complex(0);
		for (int j = 0; j < num; j++)
		{
			double re = data[j].re * cos(2 * pi * i * j / num);
			double im = -data[j].re * sin(2 * pi * i * j / num) + data[j].im * cos(2 * pi
					* i * j / num);
			dft_arr[i] += complex(re, im);
		}
	}
	return dft_arr;
}

Complex!(double)[][] transpose(Complex!(double)[][] matrix, int h, int w)
{
	Complex!(double)[][] transposed = uninitializedArray!(Complex!(double)[][])(h, w);
	for (int i = 0; i < h; i++)
	{
		for (int j = 0; j < w; j++)
		{
			transposed[j][i] = complex(0);
			transposed[j][i] = matrix[i][j];
		}
	}
	return transposed;
}

// move each quadrant
ubyte[][] shift(ubyte[][] data, int h, int w)
{
	ubyte[][] dest = uninitializedArray!(ubyte[][])(h, w);
	int c_h = h / 2;
	int c_w = w / 2;
	auto upside = data[0 .. c_h];
	auto downside = data[c_h .. h];

	for (int i = 0; i < c_h; i++)
	{
		for (int j = 0; j < c_w; j++)
		{
			dest[c_h + i][c_w + j] = upside[i][j]; // 4 <- 2
			dest[i][c_w + j] = downside[i][j]; // 1 <- 3
			dest[c_h + i][j] = upside[i][c_w + j]; // 3 <- 1
			dest[i][j] = downside[i][c_w + j]; //  2 <- 4
		}
	}
	return dest;
}
