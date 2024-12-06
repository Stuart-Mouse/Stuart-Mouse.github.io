
/*
    TODO: 
    
    we should write a template function for this that will generate the all of the required HTML and JS 
    given only the image paths and some basic layout parameters
    
    we should also add some layout variations such as multiple images side-by-side, fade-out on edges, etc
*/


function make_slideshow(slides_class_name, dots_class_name) {
    let slideshow = {
        index  : 0,
        slides : document.getElementsByClassName(slides_class_name),
        dots   : document.getElementsByClassName(dots_class_name),
    };
    show_slide(slideshow);
    return slideshow;
}

function step_slides(slideshow, n) {
    slideshow.index += n;
	show_slide(slideshow);
}

function set_slide(slideshow, n) {
	slideshow.index = n;
	show_slide(slideshow);
}

function show_slide(slideshow) {
	if (!slideshow.slides) return;
	
	if (slideshow.index >= slideshow.slides.length) slideshow.index = 0; 
	if (slideshow.index < 0) slideshow.index = slideshow.slides.length-1;
	
	for (i = 0; i < slideshow.slides.length; i++) { 
		slideshow.slides[i].style.display = "none";  
	}
	
	for (i = 0; i < slideshow.dots.length; i++) {
		slideshow.dots[i].classList.remove("active");
	}
	
	slideshow.slides[slideshow.index].style.display = "block";
	slideshow.dots[slideshow.index].classList.add("active");
}