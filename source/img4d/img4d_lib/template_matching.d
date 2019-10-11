module img4d_lib.template_matching;

import img4d;
import std.stdio, std.array, std.math,std.algorithm.iteration;

class TemplateMatching
{
	int template_height, template_width, input_height, input_width;
	ubyte[][] templateImage, inputImage;

	this(Header templateHeader, Header inputHeader, ubyte[][] templateImage, ubyte[][] inputImage)
	{
		this.template_height = templateHeader.height;
		this.template_width = templateHeader.width;
		this.input_height = inputHeader.height;
		this.input_width = inputHeader.width;
		this.templateImage = templateImage;
		this.inputImage = inputImage;
	}

	int[] SSD()
	{
		int min_ssd = int.max;
		int xpos = 0, ypos = 0;
		for (int i = 0; i < this.input_height - this.template_height; i++)
		{
			for (int j = 0; j < this.input_width - this.template_width; j++)
			{
				int ssd = 0;
				for (int h = 0; h < this.template_height; h++)
				{
					for (int w = 0; w < this.template_width; w++)
					{
						int diff = this.inputImage[i + h][j + w] - this.templateImage[h][w];
						ssd += diff * diff;
						if(ssd > min_ssd)
						{
						    break;
						}
					}
				}
				if (min_ssd > ssd)
				{
					xpos = i;
					ypos = j;
					min_ssd = ssd;
				}
			}
		}
		return [xpos, ypos];
	}

	int[] SAD()
	{
		int min_sad = int.max;
		int xpos = 0, ypos = 0;
		for (int i = 0; i < this.input_height - this.template_height; i++)
		{
			for (int j = 0; j < this.input_width - this.template_width; j++)
			{
				int sad = 0;
				for (int h = 0; h < this.template_height; h++)
				{
					for (int w = 0; w < this.template_width; w++)
					{
						int diff = this.inputImage[i + h][j + w] - this.templateImage[h][w];
						sad += abs(diff);
						if(sad > min_sad)
						{
						    break;
						}
					}
				}
				if (min_sad > sad)
				{
					xpos = i;
					ypos = j;
					min_sad = sad;
				}
			}
		}
		return [xpos, ypos];
	}
	int[] NCC()
	{
		double max_ncc = 0;
		int xpos = 0, ypos = 0;
		for (int i = 0; i < this.input_height - this.template_height; i++)
		{
			for (int j = 0; j < this.input_width - this.template_width; j++)
			{
				double ncc = 0,
				       vector = 0,
				       _magnitude_1 = 0,
				       _magnitude_2 = 0;
				for (int h = 0; h < this.template_height; h++)
				{
					for (int w = 0; w < this.template_width; w++)
					{
						vector += this.inputImage[i + h][j + w] * this.templateImage[h][w];
						double magnitude_1 = this.inputImage[i + h][j + w];
						double magnitude_2 = this.templateImage[h][w];
						_magnitude_1 += magnitude_1 * magnitude_1;
						_magnitude_2 += magnitude_2 * magnitude_2;
					}
				}
				ncc = vector / sqrt(_magnitude_1 * _magnitude_2);
				if (max_ncc < ncc)
				{
					xpos = i;
					ypos = j;
					max_ncc = ncc;
				}
			}
		}
		return [xpos, ypos];
	}

	int[] ZNCC()
	{
		double max_zncc = -1;
		int xpos = 0, ypos = 0;
		double ave_input = this.inputImage.map!(sum).sum/this.input_height*this.input_width;
		double ave_template = this.templateImage.map!(sum).sum/this.template_height*this.template_width;

		for (int i = 0; i < this.input_height - this.template_height; i++)
		{
			for (int j = 0; j < this.input_width - this.template_width; j++)
			{
				double zncc = 0,
				       vector = 0,
				       _magnitude_1 = 0,
				       _magnitude_2 = 0;
				for (int h = 0; h < this.template_height; h++)
				{
					for (int w = 0; w < this.template_width; w++)
					{
						vector += (this.inputImage[i + h][j + w] - ave_input) * (this.templateImage[h][w] - ave_template);
						double magnitude_1 = this.inputImage[i + h][j + w] - ave_input;
						double magnitude_2 = this.templateImage[h][w] - ave_template;
						_magnitude_1 += magnitude_1 * magnitude_1;
						_magnitude_2 += magnitude_2 * magnitude_2;
					}
				}
				zncc = vector / sqrt(_magnitude_1 * _magnitude_2);
				if (max_zncc < zncc)
				{
					xpos = i;
					ypos = j;
					max_zncc = zncc;
				}
			}
		}
		return [xpos, ypos];
	}

}
