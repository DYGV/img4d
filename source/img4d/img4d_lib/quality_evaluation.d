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
	double NormalizedMSE()
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

	auto SSIM()
	{

	}
}
