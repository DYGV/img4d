import std.stdio, img4d;

int main(){
	Img4d original_img = new Img4d();
	Img4d template_img = new Img4d();

	Pixel original_pix = original_img.load("../../png_img/gray_lena.png");
	Pixel template_pix = template_img.load("../../png_img/template_lena.png");
	"original image".writeln;
	writefln("Width  %8d\nHeight  %7d", original_img.header.width, original_img.header.height);
	writefln("Bit Depth  %4d\nColor Type  %3d\n", original_img.header.bitDepth, original_img.header.colorType);

	"template image".writeln;
	writefln("Width  %8d\nHeight  %7d", template_img.header.width, template_img.header.height);
	writefln("Bit Depth  %4d\nColor Type  %3d\n", template_img.header.bitDepth, template_img.header.colorType);

	auto ssd = original_img.templateMatching(template_img.header, original_img.header, 
				  template_pix.grayscale, original_pix.grayscale, original_img.MatchingType.SSD);
	"SSD calculation is done.".writeln;

	auto sad = original_img.templateMatching(template_img.header, original_img.header, 
				  template_pix.grayscale, original_pix.grayscale, original_img.MatchingType.SAD);
	"SAD calculation is done.".writeln;

	auto ncc = original_img.templateMatching(template_img.header, original_img.header, 
				  template_pix.grayscale, original_pix.grayscale, original_img.MatchingType.NCC);
	"NCC calculation is done.".writeln;
	auto zncc = original_img.templateMatching(template_img.header, original_img.header, 
				  template_pix.grayscale, original_pix.grayscale, original_img.MatchingType.ZNCC);
	"ZNCC calculation is done.".writeln;

	"SSD:\t".writeln(ssd);
	"SAD:\t".writeln(sad);
	"NCC:\t".writeln(ncc);
	"ZNCC:\t".writeln(zncc);
	
	return 0;
}
