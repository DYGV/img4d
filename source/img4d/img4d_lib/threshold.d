module img4d.img4d_lib.threshold;
import img4d, std.range;
import std.parallelism : parallel;

class Threshold{
	int height, width;
	this(Header hdr){
		this.height = hdr.height;
		this.width = hdr.width;
	}

	void simple(ref ubyte[][] gray, int thresholdValue){
		foreach(i; this.height.iota.parallel){
			for(int j; j < this.width; j++){
				gray[i][j] = gray[i][j] < thresholdValue ? 0 : 255;
			}
		}
	}

	auto adaptive(){

	}

}
