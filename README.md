RExif
=========

RExif to extract the exif data from the image.  
RExif is extract "EXIF",  "JFIF",  "JFXX" fields.

##Usage##

	var exif:RExif = new RExif();
	exif.extract( "ByteArray for image" );
	
	exif.tags; // return vector (exif data)
	exif.thumbnail; // return ByteArray (image thumbnail)
	exif.comment; // return string
	exif.imageWidth; // return uint
	exif.imageHeight; // return uint
	exif.valueForTagNum( "Tag number" ); // return * (if you need data)
	exif.valueForName( "Tag name" ); // return * (if you need data)
