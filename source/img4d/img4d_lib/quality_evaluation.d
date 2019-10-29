module img4d_lib.quality_evaluation;
import std.stdio, std.math;
import img4d;

class QualityEvaluation
{
	int height, width;
	ubyte[][] img_reference, img_evaluation;
	this(Header hdr, ubyte[][] img_reference, ubyte[][] img_evaluation)
	{
		this.height = hdr.height;
		this.width = hdr.width;
		this.img_reference = img_reference;
		this.img_evaluation = img_evaluation;
	}

	double Mean(double[] data)
	{
		double sum = 0;
		for (int i = 0; i < data.length; i++)
		{
			sum += data[i];
		}
		return sum / data.length;
	}

	double Variance(double[] data)
	{
		double sum = 0;
		double mean = this.Mean(data);
		for (int i = 0; i < data.length; i++)
		{
			double sub = data[i] - mean;
			sum += sub * sub;
		}
		return sum / data.length;
	}

	double Covariance(double[] data_x, double[] data_y)
	{
		double x_mean = this.Mean(data_x);
		double y_mean = this.Mean(data_y);
		double sum = 0;
		for (int i = 0; i < data_x.length; i++)
		{
			sum += (data_x[i] - x_mean) * (data_y[i] - y_mean);
		}
		return sum / data_x.length;
	}

	double StandardDeviation(double[] data)
	{
		return sqrt(this.Variance(data));
	}

	/*
	 *	calculate squared sum of each pixel
	 */
	double PixelSquare(ubyte[][] img)
	{
		double squared = 0;
		for (int h = 0; h < this.height; h++)
		{
			for (int w = 0; w < this.width; w++)
			{
				int pixel = this.img_evaluation[h][w];
				squared += pixel * pixel;
			}
		}
		return squared;
	}

	/*
	 *	Squared Error
	 */
	double SE()
	{
		double square_error = 0;
		for (int h = 0; h < this.height; h++)
		{
			for (int w = 0; w < this.width; w++)
			{
				int temp = this.img_reference[h][w] - this.img_evaluation[h][w];
				square_error += temp * temp;
			}
		}
		return square_error;
	}

	/*
	 *	Mean Squared Error
	 */
	double MSE()
	{
		return this.SE / (this.height * this.width);
	}

	/*
	 *	Normalized Squared Error
	 */
	double NMSE()
	{
		return this.SE / PixelSquare(this.img_evaluation);
	}

	double SNR()
	{
		return 10 * log10(this.PixelSquare(this.img_reference) / this.SE);
	}

	double PSNR()
	{
		return 20 * log10(ubyte.max / sqrt(this.MSE));
	}

	/*
	 *	Mean Structural SIMilarity
	 */
	auto MSSIM(int num_division = 4)
	{
		int h = this.height / num_division;
		int w = this.width / num_division;
		double c_1 = (0.01 * 255) * (0.01 * 255);
		double c_2 = (0.03 * 255) * (0.03 * 255);
		double[] SSIM;
		for (int counter = 0; counter < num_division; counter++)
		{
			double[] x_data;
			double[] y_data;
			for (int i = 0; i < this.height; i++)
			{
				if (i == w)
				{
					break;
				}
				for (int j = 0; j < w; j++)
				{
					if (j == w)
					{
						break;
					}
					x_data ~= this.img_reference[(counter * h) + i][(counter * w) + j];
					y_data ~= this.img_evaluation[(counter * h) + i][(counter * w) + j];
				}
			}
			double x_mean = this.Mean(x_data);
			double y_mean = this.Mean(y_data);

			double x_standardDeviation = this.StandardDeviation(x_data);
			double y_standardDeviation = this.StandardDeviation(y_data);

			double covariance = this.Covariance(x_data, y_data);
			SSIM ~= (((2 * x_mean * y_mean) + c_1) * ((2 * covariance) + c_2)) / (
					((x_mean * x_mean) + (y_mean * y_mean) + c_1) * (
					(x_standardDeviation * x_standardDeviation) + (
					y_standardDeviation * y_standardDeviation) + c_2));
		}
		return this.Mean(SSIM);
	}
}
