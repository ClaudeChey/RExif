package com.rhinoa.imagine
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	/**
	 * RExif v1.1

	 * ex)
	 * var exif:RExif = new RExif();
	 * exif.extract( bytearray );
	 * 
	 * 
	 * FF D8 FF DB // Samung D807 Jpeg file
	 * FF D8 FF E2 // Canon EOS-1D Jpeg file
	 * FF D8 FF E3 // Samsung D500 Jpeg file
	 * 
	 * 
	 */
	public class RExif
	{
		private const SOI:uint = 0xFFD8;
		private const APP0:uint = 0xFFE0; 
		private const APP1:uint = 0XFFE1;
		private const APPD:uint = 0xFFED; 
		private const APP8:uint = 0xFFE8;
		private const APPE:uint = 0xFFEF; 
		private const COM:uint = 0xFFFE;
		private const DQT:uint = 0xFFDB;
		private const DHT:uint = 0xFFC4;
		private const DRI:uint = 0xFFDD;
		private const SOF:uint = 0xFFC0;
		private const SOS:uint = 0xFFDA;
		private const EOI:uint = 0xFFD9;

		private const EXIF_TAG:uint = 0x8769;
		private const GPS_TAG:uint = 0x8825;
		private const THUM_POS_TAG:uint = 0x201;
		private const THUM_LEN_TAG:uint = 0x202;

		private var offsetEXIF:uint;
		private var offsetGPS:uint;
		private var offsetThumb:uint;
		
		private var thumbLen:uint;
		private var thumbByte:ByteArray;
		
		private var commentByte:ByteArray;
		private var commentLen:uint;
		
		private var frameWidth:uint;
		private var frameHeight:uint;
		
		private var tagsTemp:Vector.<Tag> = new Vector.<Tag>();
		public var tags:Vector.<Tag> = new Vector.<Tag>();		
		
		private const IsDebug:Boolean = false;

		
		/**
		 * getter
		 */
		public function get thumbnail():ByteArray
		{
			return thumbByte;
		}
		
		public function get imageWidth():uint
		{
			return frameWidth
		}
		
		public function get imageHeight():uint
		{
			return frameHeight
		}
		
		public function get comment():String
		{
			if ( commentLen > 0 )
			{
				commentByte.position = 0;
				return commentByte.readMultiByte( commentLen , "us-ascii" );
			}
			else return "";
		}

		public function valueForTagNum( n:uint ):*
		{
			var t:Tag;
			var i:int = -1;
			var len:int = this.tags.length;
			while ( ++i < len )
			{
				t = this.tags[i] as Tag;
				if ( t.tag == n ) return t.data;
			}
			return null;
		}
		
		public function valueForName( name:String ):*
		{
			var t:Tag;
			var i:int = -1;
			var len:int = this.tags.length;
			while ( ++i < len )
			{
				t = this.tags[i] as Tag;
				if ( t.name == name ) return t.data;
			}
			return null;
		}
		

		public function RExif( data:ByteArray = null ):void
		{
			if ( data ) this.extract( data );
		}
		
		public function extract( data:ByteArray ):void
		{
			if ( data.readUnsignedShort() != SOI ) return;
			
			// remove data
			this.dispose();

			var byte:ByteArray = new ByteArray();
			data.readBytes( byte );
			

			var id:String;
			var a:uint;
			var aByte:ByteArray;
			var rByte:ByteArray;
			var rPos:uint;
			var m:uint;
			while ( byte.bytesAvailable )
			{
				m = byte.readUnsignedShort();
				
				if ( APP0 <= m && m <= APPE )
				{
					a = byte.readUnsignedShort() - 2;
					aByte = new ByteArray();
					byte.readBytes( aByte, 0, a );
					
					switch( m )
					{
						/**
						 * Application 
						 */
						case APP0 :
							id = aByte.readUTFBytes(5).toLowerCase();
							if ( id == "jfif" )
							{
								rByte = new ByteArray();
								aByte.readBytes( rByte );
								this.parsingJFIF( rByte );
							}
							else if ( id == "jfxx" )
							{
								rByte = new ByteArray();
								aByte.readBytes( rByte );
								this.parsingJFXX( rByte );
							}
							break;
							 
						case APP1 :
							id = aByte.readUTFBytes(6).toLowerCase();
							if ( id == "exif" )
							{
								rByte = new ByteArray();
								aByte.readBytes( rByte );
								this.parsingEXIF( rByte );
							}
							break;

						default :
							aByte.position = 0;
							rByte = new ByteArray();
							aByte.readBytes( rByte );
							break;
					}
				}
				else if ( m == DQT )
				{
					a = byte.readUnsignedShort() - 2;
					aByte = new ByteArray();
					byte.readBytes( aByte, 0, a );					
				}
				else if ( m == DHT )
				{
					a = byte.readUnsignedShort() - 2;
					aByte = new ByteArray();
					byte.readBytes( aByte, 0, a );					
				}
				else if ( m == DRI )
				{
					a = byte.readUnsignedShort() - 2;
					aByte = new ByteArray();
					byte.readBytes( aByte, 0, a );
				}
				else if ( m == SOF )
				{
					a = byte.readUnsignedShort() - 2;
					aByte = new ByteArray();
					byte.readBytes( aByte, 0, a );	
					this.frameHeight = aByte.readUnsignedShort();
					this.frameWidth = aByte.readUnsignedShort();
				}
				else if ( m == SOS )
				{
					a = byte.readUnsignedShort() - 2;
					aByte = new ByteArray();
					byte.readBytes( aByte, 0, a );
				}
				else if ( m == COM )
				{
					commentLen = byte.readUnsignedShort() - 2;
					commentByte = new ByteArray();
					byte.readBytes( commentByte, 0, commentLen );
				}
				else
				{
					a = byte.readUnsignedShort() - 2;
					byte.position += a;
				}
			}
			
		}
		
		private function parsingJFXX( appbyte:ByteArray ):void
		{
			var t:uint = appbyte.readUnsignedByte();
			
			var xt:uint;
			var yt:uint;
			switch( t )
			{
				case 0x10: // jpeg
					thumbByte = new ByteArray();
					appbyte.readBytes( thumbByte, 0, appbyte.length - 2 );
					break;
					
				case 0x11: // 256 color bitmap
					xt = appbyte.readUnsignedByte();
					yt = appbyte.readUnsignedByte();
					break;
					
				case 0x12:
					xt = appbyte.readUnsignedByte();
					yt = appbyte.readUnsignedByte();
					break;
			}
		
		}
		
		private function parsingJFIF( appByte:ByteArray ):void
		{
			var v1:uint = appByte.readUnsignedByte();
			var v2:uint = appByte.readUnsignedByte();
			var u:uint = appByte.readUnsignedByte();
			var xd:uint = appByte.readUnsignedShort();
			var yd:uint = appByte.readUnsignedShort();
			var xt:uint = appByte.readUnsignedByte();
			var yt:uint = appByte.readUnsignedByte();			
		}
		
		private function parsingEXIF( appByte:ByteArray ):void
		{
			var endian:String = appByte.readUTFBytes(2);
			if ( endian == "MM" ) appByte.endian = Endian.BIG_ENDIAN;
			else if ( endian == "II" ) appByte.endian = Endian.LITTLE_ENDIAN;
						
			var tiffID:uint = appByte.readUnsignedShort();
			var offsetIFD0:uint = appByte.readUnsignedInt();
			appByte.position = offsetIFD0; // move to 0th IFD 
			
			/* 0th IFD */		
			try
			{
				var len:uint = this.parseing( appByte, offsetIFD0 );
			}
			catch ( e:Error )
			{
			}
			
			/* 1th IFD */		
			try
			{
				appByte.position = offsetIFD0 + 2 + (12 * len);
				var offsetIFD1:uint = appByte.readUnsignedInt(); // 4byte byte end
				this.parseing( appByte, offsetIFD1 );
			}
			catch ( e:Error )
			{
			}
			
			if ( offsetEXIF  )
			{
				/* EXIF IFD */		
				try
				{
					this.parseing( appByte, offsetEXIF );
				}
				catch ( e:Error )
				{
				}
			}
			
			if ( offsetGPS )
			{
				/* GPS IFD */	
				try
				{
					this.parseing( appByte, offsetGPS );
				}
				catch ( e:Error )
				{
				}
			}
			
			/* Exif Thumbnail */
			if ( this.offsetThumb == 0 && this.thumbLen == 0 ) return;
			
			try
			{
				thumbByte = new ByteArray();
				appByte.position = this.offsetThumb;
				appByte.readBytes( thumbByte, 0, thumbLen );
				thumbByte.endian = appByte.endian;
			}
			catch ( e:Error )
			{
			}

		}
		
		
		
		private function parseing( appByte:ByteArray, offset:uint ):uint
		{
			appByte.position = offset;
			
			var tempByte:ByteArray;
			var tempCount:uint;
			var t:Tag;
			var len:uint = appByte.readUnsignedShort();
			var i:int = -1;
			while ( ++i < len )
			{
				appByte.position = offset + 2 + (i * 12);
					
				t = new Tag();
				t.tag = appByte.readUnsignedShort();
				t.type = appByte.readUnsignedShort();
				t.count = appByte.readUnsignedInt();
				t.offset = appByte.readUnsignedInt();
				t.name = this.compareTagNum( t.tag );
				tags.push( t );
				

				if ( this.typeByteTotal(t.type, t.count) > 4 )
				{
					tempByte = new ByteArray();
					appByte.position = t.offset;
					appByte.readBytes( tempByte, 0, this.typeByteTotal(t.type, t.count) );
					tempByte.endian = appByte.endian;
				}
				else
				{
					appByte.position -= 4;
					tempByte = new ByteArray();
					appByte.readBytes( tempByte, 0, 4 );
					tempByte.endian = appByte.endian;
				}
				t.data = this.actualData( t.type, t.count, tempByte );
				
				switch( t.tag )
				{
					case EXIF_TAG:
						this.offsetEXIF = t.data;
						break;
						
					case GPS_TAG:
						this.offsetGPS = t.data;
						break;
						
					case THUM_POS_TAG:
						this.offsetThumb = t.data;
						break;
						
					case THUM_LEN_TAG:
						this.thumbLen = t.data;
						break;
				}
				
				if ( t.name == null )
				{
					t = tags.pop();
					this.disposeTag(t );
				}
			}
			return len;
		}
	
		private function getEmptyTag():Tag
		{
			var t:Tag;
			if ( tagsTemp.length > 0 ) t = tagsTemp.shift();
			else t = new Tag();
			return t;
		}
		
		private function dispose():void
		{
			var t:Tag;
			while ( 0 < tags.length )
			{
				t = tags.shift();
				this.disposeTag( t );
			}
			
			offsetEXIF = 0;
			offsetGPS = 0;
			offsetThumb = 0;
			
			thumbLen = 0;
			thumbByte = null;
			
			commentByte = null;
			commentLen = 0;
			
			frameWidth = 0;
			frameHeight = 0;
		}
		
		private function disposeTag( t:Tag ):void
		{
			t.count = 0;
			t.data = 0;
			t.name = "";
			t.offset = 0;
			t.tag = 0;
			t.type = 0;
			this.tagsTemp.push( t );
		}
	
		private function actualData( type:uint, count:uint, byte:ByteArray ):*
		{
			byte.position = 0;
			var data:* = 0;
			var i:int = -1;
			
			switch( type )
			{
				case 1: // byte
					data = byte.readUnsignedByte();
					break;
					
				case 2: // ascii(byteArray)
					data = byte.readMultiByte( this.typeByteTotal(type, count), "us-ascii" );
					break;
					
				case 3: // short(uint16)
					data = byte.readUnsignedShort();
					break;
					
				case 4: // long(uint32)
					while ( ++i < count ) data += byte.readUnsignedInt();
					break;
					
				case 5: // rational(2xuint32)
					while ( ++i < count ) data += byte.readUnsignedInt();
					break;
					
				case 9: // slong(int32)
					while ( ++i < count ) data += byte.readInt();
					break;

				case 7: // undefined(byteArra)				
				case 10: // srational(2xint32)
				default:
					break;
			}
			return data;
		}
		
		
		private function typeByteTotal( type:uint, count:uint):uint
		{
			switch( type )
			{
				case 1: // byte
				case 2: // ascii(byteArray)
				case 7: // undefined(byteArra)
					return 1 * count;
					break;
					
				case 3: // short(uint16)
					return 2 * count;
					break;
					
				case 4: // long(uint32)
				case 9: // slong(int32)				
					return 4 * count;
					break;
					
				case 5: // rational(2xuint32)
				case 10: // srational(2xint32)
					return 8 * count;
					break;
					
				default :
					return 0;
					break;
			}
		}
		
		
		private function compareTagNum( n:uint ):String
		{
			switch( n )
			{
				case 0:
					return "GPSVersionID";
					break;

				case 1:
					return "GPSLatitudeRef";
					break;

				case 2:
					return "GPSLatitude";
					break;

				case 3:
					return "GPSLongitudeRef";
					break;

				case 4:
					return "GPSLongitude";
					break;

				case 5:
					return "GPSAltitudeRef";
					break;

				case 6:
					return "GPSAltitude";
					break;

				case 7:
					return "GPSTimeStamp";
					break;

				case 8:
					return "GPSSatellites";
					break;

				case 9:
					return "GPSStatus";
					break;

				case 10:
					return "GPSMeasureMode";
					break;

				case 11:
					return "GPSDOP";
					break;

				case 12:
					return "GPSSpeedRef";
					break;

				case 13:
					return "GPSSpeed";
					break;

				case 14:
					return "GPSTrackRef";
					break;

				case 15:
					return "GPSTrack";
					break;

				case 16:
					return "GPSImgDirectionRef";
					break;

				case 17:
					return "GPSImgDirection";
					break;

				case 18:
					return "GPSMapDatum";
					break;

				case 19:
					return "GPSDestLatitudeRef";
					break;

				case 20:
					return "GPSDestLatitude";
					break;

				case 21:
					return "GPSDestLongitudeRef";
					break;

				case 22:
					return "GPSDestLongitude";
					break;

				case 23:
					return "GPSDestBearingRef";
					break;

				case 24:
					return "GPSDestBearing";
					break;

				case 25:
					return "GPSDestDistanceRef";
					break;

				case 26:
					return "GPSDestDistance";
					break;

				case 27:
					return "GPSProcessingMethod";
					break;

				case 28:
					return "GPSAreaInformation";
					break;

				case 29:
					return "GPSDateStamp";
					break;

				case 30:
					return "GPSDifferential";
					break;

				case 256:
					return "ImageWidth";
					break;

				case 257:
					return "ImageLength";
					break;

				case 258:
					return "BitsPerSample";
					break;

				case 259:
					return "Compression";
					break;
					/**
					 * 
					1		= Uncompressed
					2		= CCITT 1D
					3		= T4/Group 3 Fax
					4		= T6/Group 4 Fax
					5		= LZW
					6		= JPEG (old-style)
					7		= JPEG
					8		= Adobe Deflate
					9		= JBIG B&W
					10		= JBIG Color
					99		= JPEG
					262		= Kodak 262
					32766	= Next
					32767	= Sony ARW Compressed
					32769	= Packed RAW
					32770	= Samsung SRW Compressed
					32771	= CCIRLEW
					32773	= PackBits
					32809	= Thunderscan
					32867	= Kodak KDC Compressed
					32895	= IT8CTPAD
					32896	= IT8LW
					32897	= IT8MP
					32898	= IT8BL
					32908	= PixarFilm
					32909	= PixarLog
					32946	= Deflate
					32947	= DCS
					34661	= JBIG
					34676	= SGILog
					34677	= SGILog24
					34712	= JPEG 2000
					34713	= Nikon NEF Compressed
					34715	= JBIG2 TIFF FX
					34718	= Microsoft Document Imaging (MDI) Binary Level Codec
					34719	= Microsoft Document Imaging (MDI) Progressive Transform Codec
					34720	= Microsoft Document Imaging (MDI) Vector
					65000	= Kodak DCR Compressed
					65535	= Pentax PEF Compressed
					 * 
					 */
					
				case 262:
					return "PhotometricInterpretation";
					break;

				case 266:
					return "FillOrder";
					break;

				case 269:
					return "DocumentName";
					break;

				case 270:
					return "ImageDescription";
					break;

				case 271:
					return "Make";
					break;

				case 272:
					return "Model";
					break;

				case 273:
					return "StripOffsets";
					break;

				case 274:
					return "Orientation";
					break;

				case 277:
					return "SamplesPerPixel";
					break;

				case 278:
					return "RowsPerStrip";
					break;

				case 279:
					return "StripByteCounts";
					break;

				case 282:
					return "XResolution";
					break;

				case 283:
					return "YResolution";
					break;

				case 284:
					return "PlanarConfiguration";
					break;

				case 296:
					return "ResolutionUnit";
					break;

				case 301:
					return "TransferFunction";
					break;

				case 305:
					return "Software";
					break;

				case 306:
					return "DateTime";
					break;

				case 315:
					return "Artist";
					break;

				case 318:
					return "WhitePoint";
					break;

				case 319:
					return "PrimaryChromacities";
					break;

				case 342:
					return "TransferRange";
					break;

				case 512:
					return "JPEGProc";
					break;

				case 513:
					return "JPEGInterchangeFormat";
					break;

				case 514:
					return "JPEGInterchangeFormatLength";
					break;

				case 529:
					return "YCbCrCoefficients";
					break;

				case 530:
					return "YCbCrSubSampling";
					break;

				case 531:
					return "YCbCrPositioning";
					break;

				case 532:
					return "ReferenceBlackWhite";
					break;

				case 33421:
					return "CFARepeatPatternDim";
					break;

				case 33422:
					return "CFAPattern";
					break;

				case 33423:
					return "BatteryLevel";
					break;

				case 33432:
					return "Copyright";
					break;

				case 33434:
					return "ExposureTime";
					break;

				case 33437:
					return "FNumber";
					break;

				case 33723:
					return "IPTC/NAA";
					break;

				case 34665:
					return "Exif IFD Pointer";
					break;

				case 34675:
					return "InterColorProfile";
					break;

				case 34850:
					return "ExposureProgram";
					break;

				case 34852:
					return "SpectralSensitivity";
					break;

				case 34853:
					return "GPSInfo";
					break;

				case 34855:
					return "ISOSpeedRatings";
					break;

				case 34856:
					return "OECF";
					break;

				case 36864:
					return "ExifVersion";
					break;

				case 36867:
					return "DateTimeOriginal";
					break;

				case 36868:
					return "DateTimeDigitized";
					break;

				case 37121:
					return "ComponentsConfiguration";
					break;

				case 37122:
					return "CompressedBitsPerPixel";
					break;

				case 37377:
					return "ShutterSpeedValue";
					break;

				case 37378:
					return "ApertureValue";
					break;

				case 37379:
					return "BrightnessValue";
					break;

				case 37380:
					return "ExposureBiasValue";
					break;

				case 37381:
					return "MaxApertureValue";
					break;

				case 37382:
					return "SubjectDistance";
					break;

				case 37383:
					return "MeteringMode";
					break;

				case 37384:
					return "LightSource";
					break;
					/**
					 * 
					0	= Unknown					15	= White Fluorescent
					1	= Daylight					16	= Warm White Fluorescent
					2	= Fluorescent				17	= Standard Light A
					3	= Tungsten (Incandescent)	18	= Standard Light B
					4	= Flash						19	= Standard Light C
					9	= Fine Weather				20	= D55
					10	= Cloudy					21	= D65
					11	= Shade						22	= D75
					12	= Daylight Fluorescent		23	= D50
					13	= Day White Fluorescent		24	= ISO Studio Tungsten
					14	= Cool White Fluorescent	255	= Other
					 * 
					 */					
					

				case 37385:
					return "Flash";
					break;
					/**
					 * 
					0x0		= No Flash
					0x1		= Fired
					0x5		= Fired, Return not detected
					0x7		= Fired, Return detected
					0x8		= On, Did not fire
					0x9		= On, Fired
					0xd		= On, Return not detected
					0xf		= On, Return detected
					0x10	= Off, Did not fire
					0x14	= Off, Did not fire, Return not detected
					0x18	= Auto, Did not fire
					0x19	= Auto, Fired
					0x1d	= Auto, Fired, Return not detected
					0x1f	= Auto, Fired, Return detected
					0x20	= No flash function
					0x30	= Off, No flash function
					0x41	= Fired, Red-eye reduction
					0x45	= Fired, Red-eye reduction, Return not detected
					0x47	= Fired, Red-eye reduction, Return detected
					0x49	= On, Red-eye reduction
					0x4d	= On, Red-eye reduction, Return not detected
					0x4f	= On, Red-eye reduction, Return detected
					0x50	= Off, Red-eye reduction
					0x58	= Auto, Did not fire, Red-eye reduction
					0x59	= Auto, Fired, Red-eye reduction
					0x5d	= Auto, Fired, Red-eye reduction, Return not detected
					0x5f	= Auto, Fired, Red-eye reduction, Return detected
					 * 
					 */

				case 37386:
					return "FocalLength";
					break;

				case 37500:
					return "MakerNote";
					break;

				case 37510:
					return "UserComment";
					break;

				case 37520:
					return "SubSecTime";
					break;

				case 37521:
					return "SubSecTimeOriginal";
					break;

				case 37522:
					return "SubSecTimeDigitized";
					break;

				case 40960:
					return "FlashPixVersion";
					break;

				case 40961:
					return "ColorSpace";
					break;

				case 40962:
					return "PixelXDimension";
					break;

				case 40963:
					return "PixelYDimension";
					break;

				case 40963:
					return "RelatedSoundFile";
					break;

				case 40965:
					return "InteroperabilityOffset";
					break;

				case 41483:
					return "FlashEnergy";
					break;

				case 41484:
					return "SpatialFrequencyResponse";
					break;

				case 41486:
					return "FocalPlaneXResolution";
					break;

				case 41487:
					return "FocalPlaneYResolution";
					break;

				case 41488:
					return "FocalPlaneResolutionUnit";
					break;

				case 41492:
					return "SubjectLocation";
					break;

				case 41493:
					return "ExposureIndex";
					break;

				case 41495:
					return "SensingMethod";
					break;

				case 41728:
					return "FileSource";
					break;

				case 41729:
					return "SceneType";
					break;

				case 41730:
					return "CFAPattern";
					break;

				case 41985:
					return "CustomRendered";
					break;

				case 41986:
					return "ExposureMode";
					break;

				case 41987:
					return "WhiteBalance";
					break;

				case 41988:
					return "DigitalZoomRatio";
					break;

				case 41989:
					return "FocalLengthIn35mmFilm";
					break;

				case 41990:
					return "SceneCaptureType";
					break;

				case 41991:
					return "GainControl";
					break;

				case 41992:
					return "Contrast";
					break;

				case 41993:
					return "Saturation";
					break;

				case 41994:
					return "Sharpness";
					break;

				case 41995:
					return "DeviceSettingDescription";
					break;

				case 41996:
					return "SubjectDistanceRange";
					break;

				case 42016:
					return "ImageUniqueID";
					break;

				case 50341:
					return "PrintIM";
					break;
					
				case 59932:
					return "Padding";
					break;
					
				case 59933: // Microsoft's ill-conceived maker note offset difference
					return "OffsetSchema";
					break;
			}

			return null;
		}
		
		
		private function debug( obj:String ):void
		{
			if ( IsDebug ) trace( obj );
		}

		
	}
}



class Tag
{
	public var name:String;
	public var tag:uint;
	public var type:uint;
	public var count:uint;
	public var offset:uint;
	public var data:* = 0;
}
