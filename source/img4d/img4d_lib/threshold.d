module img4d_lib.threshold;
import img4d;

class Threshold
{
	int height, width;
	ubyte[][] grayscale;
	this(Header hdr, ubyte[][] gray)
	{
		this.height = hdr.height;
		this.width = hdr.width;
		this.grayscale = gray;
	}

	auto simple(int thresholdValue)
	{
		ubyte[][] binary;
		binary.length = this.height;
		for (int i = 0; i < this.height; i++)
		{
			for (int j; j < this.width; j++)
			{
				binary[i] ~= this.grayscale[i][j] < thresholdValue ? 0 : 255;
			}
		}
		return binary;
	}

	auto adaptive()
	{

	}

}
