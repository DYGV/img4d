module img4d_lib.fourier;

import img4d;
import std.stdio, std.array, std.conv, std.range, std.algorithm, std.math, std.complex;

class Fourier
{
	int height, width;
	this(Header hdr)
	{
		this.height = hdr.height;
		this.width = hdr.width;
	}

	Complex!(double)[] dft(Complex!(double)[] data, bool isDFT)
	{
		Complex!(double)[] dft_arr;
		dft_arr.length = this.width;
		double pi = PI;
		double im, re = 0;

		for (int i = 0; i < this.width; i++)
		{
			dft_arr[i] = complex(0);
			double theta = 2 * pi * i / this.width;
			for (int j = 0; j < this.width; j++)
			{
				double sin_theta = sin(j * theta);
				double cos_theta = cos(j * theta);
				if (isDFT)
				{
					re = data[j].re * cos_theta + data[j].im * sin_theta;
					im = -data[j].re * sin_theta + data[j].im * cos_theta;
				}
				else // invserse DFT
				{
					re = data[j].re * cos_theta - data[j].im * sin_theta;
					im = data[j].re * sin_theta + data[j].im * cos_theta;
				}
				dft_arr[i] += complex(re, im);
			}
		}
		return dft_arr;
	}

	Complex!(double)[][] transpose(Complex!(double)[][] matrix)
	{
		Complex!(double)[][] transposed = uninitializedArray!(Complex!(double)[][])(this.height,
				this.width);
		for (int i = 0; i < this.height; i++)
		{
			for (int j = 0; j < this.width; j++)
			{
				transposed[j][i] = complex(0);
				transposed[j][i] = matrix[i][j];
			}
		}
		return transposed;
	}

	// move each quadrant
	T[][] shift(T)(T[][] data)
	{
		T[][] dest = uninitializedArray!(T[][])(this.height, this.width);
		int c_h = this.height / 2;
		int c_w = this.width / 2;
		auto upside = data[0 .. c_h];
		auto downside = data[c_h .. this.height];

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

	ubyte fit_to_ubyte(in double value)
	{
		return (value < ubyte.min ? ubyte.min : value > ubyte.max ? ubyte.max : value).to!ubyte;
	}
}
