#!/bin/bash

# visualise data using ImageMagick

CONVERT=/usr/local/ImageMagick/bin/convert

# This script expects ImageMagick, or a similar program, to be installed
# GraphicsMagick may be an alternative if ImageMagick is unavailable

VERSION="0.1 alpha, 20120131"
COPYRIGHT="Copyright Tim Wilson-Brown, 2012"
# Email me for additional permissions
# twilsonb at mac dot com
WARRANTY="$0 comes with ABSOLUTELY NO WARRANTY"
LICENCE="$0 is freely distributable under the GNU GPL Version 3 or later."

# visualise is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

# This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

# command for removing temp files
RM="echo Keeping for debugging: "
#RM=rm -f

# if you know the endianness of your data, and it matters, specify it with:
# MSB or LSB
INPUT_ENDIAN=MSB

# Some files have known headers. Use this parameter to skip them.
HEADER_SKIP=0

# When using unpadded images, or custom heights,
#   certain output image types (such as tiff) are not recommended,
#   as they will split the visualisation into multiple image pages
#   if the specified size is too small to contain the input data

# when automatically scaling, keep the image within these limits
SCALE_MAX_WIDTH=1200
SCALE_MAX_HEIGHT=900

# Annotation settings are located at the end of the file
# Annotation may be useless or fail if the data is too long
# So we switch them off if the scale factor gets too low

if [ $# -lt 1 ]; then
    echo "$0 $VERSION"
    echo "$COPYRIGHT"
    echo "$WARRANTY"
    echo "$LICENCE"
    echo ""
    echo "usage: $0 input-file [ scale [ width [ height [ image-type [ output-file ] ] ] ]"
    echo ""
    echo "visualise a data file using ImageMagick's convert"
    echo "  as an image with the specified format, width and height,"
    echo "  scaled so each input pixels is scale x scale pixels"
    echo "the final row of pixels is automatically padded with 0 bytes"
    echo "  to produce a rectangular image if needed"
    echo ""
    echo "if scale is unspecified or 0, the default is an integral scale,"
    echo "  with output <= ${SCALE_MAX_WIDTH}x${SCALE_MAX_HEIGHT}"
    echo "if width is unspecified or 0, the default is a padded squarish image"
    echo "if height is unspecified or 0, the default is padded using width"
    echo ""
    echo "if input-file is -, data is read from standard input"
    echo "if output-file is not specified, it is input-file.image-type"
    echo "  output-file can also be - for standard output"
    echo ""
    echo "if image-type is not specified, the default is png"
    echo "  lossless formats are recommended for image-type"
    exit 1
else
    INPUT_FILE="$1"
fi

if [ $# -lt 2 ]; then
    SCALE=0
elif [ "0$2" -lt 1 ]; then
    SCALE=0
else 
    SCALE=$2
fi


if [ $# -lt 3 ]; then
    WIDTH=0
elif [ "0$3" -lt 1 ]; then
    WIDTH=0
else 
    WIDTH=$3
fi


if [ $# -lt 4 ]; then
    HEIGHT=0
elif [ "0$4" -lt 1 ]; then
    HEIGHT=0
else
    HEIGHT=$4
fi


if [ $# -lt 5 ]; then
    OUTPUT_TYPE=png
else
    OUTPUT_TYPE="$5"
fi


# no-one really wants a file called "-.png"
if [ $# -lt 6 ]; then
    OUTPUT_FILE="$INPUT_FILE"."$OUTPUT_TYPE"
else
    OUTPUT_FILE="$6"
fi


# Visualisation parameters

# RGB = 3, floating-point = 3*depth/8
PIXEL_BYTES=3

# To Visualise floating point values in Little-Endian Format:
# -depth 8 is half-precision, 16 is single-precision, 32 is double-precision
# -define quantum:format=floating-point -depth 16 -endian LSB

# cmyk or gray are also options
INPUT_TYPE=rgb

# increase to get more detailed colours
# this is the depth in bits per channel per pixel (e.g. R = 8 bits in RGB)
INPUT_DEPTH_BITS=8


# dd doesn't like - as stdin
if [ "x$INPUT_FILE" = "x-" ]; then
    DD_INPUT_FILE=/dev/stdin
else
    DD_INPUT_FILE="$INPUT_FILE"
fi


# use 2>&- after a command, or remove -verbose, to remove debugging output


# if width wasn't specified, we need to tell dd the width 
# which produces a square image from the data size
# therefore, we use a temp file to determine the size from stdin

SCRIPT_NAME=`basename "$0" .sh`
    
AUTO_WIDTH=""
if [ "$WIDTH" -eq 0 ]; then
    AUTO_WIDTH="(auto)"

    DDIF_TMP_FILE=`mktemp -t "$SCRIPT_NAME".ddif.$$` || exit 1

    cat "$INPUT_FILE" > "$DDIF_TMP_FILE"
    DATA_BYTES=`cat "$DDIF_TMP_FILE" | wc -c`

    # we use a power of 2 for the width, increasing it until the height
    # is roughly equal - the *3/2 allows for larger widths than heights
    # and makes elongated sizes less likely
    # e.g. 64x65 doesn't turn into 128x33
    WIDTH=1
    while [ $[$DATA_BYTES/$PIXEL_BYTES/$WIDTH] -gt $[$WIDTH*3/2] ]; do
	WIDTH=$[$WIDTH*2]
    done

    DD_INPUT_FILE="$DDIF_TMP_FILE"
fi


# we need to tell convert how many rows dd writes
# therefore, we use a temp file
# this could be skipped if HEIGHT is specified, but it's inflexible
DDOF_TMP_FILE=`mktemp -t "$SCRIPT_NAME".ddof.$$` || exit 1

# if height was specified, we limit dd to this number of output rows
if [ "$HEIGHT" -eq 0 ]; then
    DD_COUNT=
else
    # assumes ibs=1
    DD_COUNT="count=$[$HEIGHT*$WIDTH*$PIXEL_BYTES]"
fi

# pad input using dd to a full number of image rows,
#   otherwise, an error occurs and the last row of output pixels is lost

DD_REPORT=`dd if="$DD_INPUT_FILE" of="$DDOF_TMP_FILE" skip=$HEADER_SKIP $DD_COUNT ibs=1 obs=$[$WIDTH*$PIXEL_BYTES] conv=osync 2>&1 | tr "\n" ","` || exit 1

# don't remove $DD_INPUT_FILE because it could be the original data
$RM $DDIF_TMP_FILE


# find the number of image rows written
echo "Bytes In, Image Height, Bytes Out:"
echo "$DD_REPORT"

echo Input File: "$INPUT_FILE"
echo Header Bytes: $HEADER_SKIP "(skipped)"
BYTES_READ=`echo "$DD_REPORT" | cut -f 1 -d , | cut -f -1 -d +` || exit 1
echo Bytes Read: $BYTES_READ
echo Output File: "$OUTPUT_FILE"
echo Type: "$OUTPUT_TYPE"
echo Width: $WIDTH $AUTO_WIDTH

# calculate auto height if needed
if [ "$HEIGHT" -eq 0 ]; then
    HEIGHT=`echo "$DD_REPORT" | cut -f 2 -d , | cut -f -1 -d +` || exit 1
    echo Height: $HEIGHT "(auto)"
else
    echo Height: $HEIGHT
fi

# calculate auto scale if needed: the resulting image must stay within
#   the max scale width and height
if [ "$SCALE" -eq 0 ]; then

    SCALE_W=$[$SCALE_MAX_WIDTH/$WIDTH]
    SCALE_H=$[$SCALE_MAX_HEIGHT/$HEIGHT]

    if [ $SCALE_W -lt $SCALE_H ]; then
	SCALE=$SCALE_W
    else
	SCALE=$SCALE_H
    fi

    # it's a big one - about 3Mb
    if [ $SCALE -eq 0 ]; then
	SCALE=1
    fi

    echo Scale: $SCALE "(auto)"
else
    echo Scale: $SCALE
fi

echo Bytes Per Pixel: $PIXEL_BYTES


# create byte labels for the total bytes and pixel positions
#   these labels become too small once the zoom level drops below about 8 or 10
#   use HEADER_SKIP, WIDTH, and HEIGHT to read large files in chunks
#     with annotations

# ImageMagick 6.6.5 on Mac OS X needs an explicit font path
#   because its fallback method (gs) fails
# Any ttf or ttc can be used - try HelveticaLight.ttf for a proportional font
FONT_PATH="/System/Library/Fonts/Menlo.ttc"
FONT_SIZE=$[$SCALE-1]
# how wide and high we should print hex digits
W_HEX_DIGITS=4
H_HEX_DIGITS=2

# write to a file to make it easier to work with
LABEL_TMP_FILE=`mktemp -t "$SCRIPT_NAME".label.$$` || exit 1


byteshex=`printf "0x%.${W_HEX_DIGITS}x" $[$BYTES_READ]`
echo "-annotate +$[$SCALE*1/2]+$[$FONT_SIZE/2] $byteshex" >> "$LABEL_TMP_FILE"

# calculate the width byte counts
for (( i=0; i<$WIDTH; i++ )); do
    ihex=`printf "%.${H_HEX_DIGITS}x" $[$i*$PIXEL_BYTES]`
    # if present, put hex second last digit labels 
    #   centred in first row in corresponding columns
    i2last=${ihex:(-2):1}
    if [ "x$i2last" != "x" ]; then
	echo "-annotate +$[$SCALE*(4+$i)+$FONT_SIZE/4]+$[0] $i2last" >> "$LABEL_TMP_FILE"
    fi
    # put hex last digit labels centred in the second row
    #   in corresponding columns
    ilast=${ihex:(-1):1}
    echo "-annotate +$[$SCALE*(4+$i)+$FONT_SIZE/4]+$[$FONT_SIZE] $ilast" >> "$LABEL_TMP_FILE"
done

# calculate the height byte counts
for (( i=0; i<$HEIGHT; i++ )); do
    counthex=`printf "0x%.${W_HEX_DIGITS}x" $[$i*$WIDTH*$PIXEL_BYTES]`
    # put hex byte count labels of width $HEX_DIGITS next to the image
    #   in corresponding rows
    echo "-annotate +$[$SCALE*1/2]+$[$SCALE*(2+$i)] $counthex" >> "$LABEL_TMP_FILE"
done

# prepare convert sub-commands
# disabling these commands improves performance and stability on large files
if [ $SCALE -eq 1 ]; then
    SCALE_CMD=""
else
    SCALE_CMD="-scale $[$WIDTH*$SCALE]x$[$HEIGHT*$SCALE]"
fi


if [ $SCALE -lt 8 ]; then
    ANN_CMD=""
else
    ANN_CMD="\
 -gravity SouthEast -background LightGrey \
   -extent $[($WIDTH+$W_HEX_DIGITS)*$SCALE]x$[($HEIGHT+$H_HEX_DIGITS)*$SCALE] \
 -gravity NorthWest -fill black -font "$FONT_PATH" -pointsize $FONT_SIZE \
   `cat \"$LABEL_TMP_FILE\"`"
fi


$CONVERT -verbose \
  -size ${WIDTH}x${HEIGHT} -depth $INPUT_DEPTH_BITS -endian $INPUT_ENDIAN \
    "${INPUT_TYPE}":"${DDOF_TMP_FILE}" \
  $SCALE_CMD $ANN_CMD "${OUTPUT_TYPE}":"${OUTPUT_FILE}"

# save and exit with convert's status after removing temp files
CONVERT_EXIT=$?

$RM $DDOF_TMP_FILE
$RM $LABEL_TMP_FILE

exit $CONVERT_EXIT
