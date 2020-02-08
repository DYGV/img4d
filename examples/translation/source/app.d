import img4d;

int main(){
	Img4d img = new Img4d();
	// Img4d translation_img = new Img4d();

	Pixel original_pix = img.load("../../png_img/gray_lena.png");
	// translation_img = img;

	// origin is original_pix.grayscale[img.header.height-1][0]
	int transition_x = 100;
	int transition_y = -200;
	Pixel transformed = img.translate(original_pix.grayscale, transition_x, transition_y);
	img.save(transformed, "../../png_img/translation_lena.png");
	return 0;
}


