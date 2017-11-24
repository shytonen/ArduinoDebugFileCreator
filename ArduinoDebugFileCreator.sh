#! /bin/bash

################################################
# Created by shytonen (s.hytonen@hotmail.com)  #
# 13. Nov 2017                                 #
#                                              #
# Builds a debug file for arduino to debug     #
# self-written or third-party libraries.       #
#                                              #
################################################


if [ $# -ne 2 ] && [ $# -ne 3 ] ;
then
	echo Usage: $0 program.ino library_path [output_file];
	echo;
	exit;
fi

INPUT_FILE=`realpath $1`
INPUT_PATH=`dirname $INPUT_FILE`
LIB_PATH=`realpath $2`
OUTPUT_FILE=''
OUTPUT_PATH=''

if [ $# -eq 2 ] ; 
then
	OUTPUT_FILE="$PWD/arduino_debug.ino";

else
	OUTPUT_FILE=`realpath $3`;
fi

OUTPUT_PATH=`dirname $OUTPUT_FILE`

# Create files
echo -n '' >"$OUTPUT_FILE";
echo -n '' >"$OUTPUT_PATH/includeFiles";


function FindHeaderFilesFromPath {
	for file in $1 ;
	do
		# If the file is .h, .c, .cpp or .ino type
		if [ -f $file ] ;
		then
		if [[ $file == *.h || $file == *.cpp || $file == *.ino || $file == *.c ]] ;
		then
			# Collect all the include files found and save them to a file
			# Remove the first and the last characters " " or < >
			# Remove also file type accronym .h from the name
			# Remove subfolder path if given (#include <subfolder/library>)
			# Remove whitespaces
			# Remove \r character that appears weirdly from somewhere
			cat $file \
			|grep "#include" \
			|awk -F " " '{print $2}' \
			|sed 's/["<>]//g' \
			|sed 's/\.h//g' \
			|sed 's/.\+\///g' \
			|sed 's/\ //g' \
			|sed 's/\r//g' \
			>>"$OUTPUT_PATH/includeFiles";
		fi; fi
	done
}

# Find header files from LIB_PATH and its subdirectories
FindHeaderFilesFromPath "$INPUT_PATH/*"
FindHeaderFilesFromPath "$LIB_PATH/*"
FindHeaderFilesFromPath "$LIB_PATH/*/*"
FindHeaderFilesFromPath "$LIB_PATH/*/*/*"

# Remove duplicate include files
sort "$OUTPUT_PATH/includeFiles" |uniq >"$OUTPUT_PATH/sortedIncludes";
rm "$OUTPUT_PATH/includeFiles";

# Create list of libraries for the dialog
liblist=""
n=1
for lib in $(cat $OUTPUT_PATH/sortedIncludes) ;
do
	liblist="$liblist $lib $n off";
	n=$[n+1];
done

rm "$OUTPUT_PATH/sortedIncludes";

overwrittenLibraries='';

# Start the dialog
choices=$(dialog --stdout --checklist 'Select libraries to debug:' 40 60 60 $liblist);

#sortedChoices=$(dialog --stdout --radiolist $choices 'Sort libraries:' 40 60 60 --cancel-label "Move up");


# Prepare include files for selection dialog
echo -n "" >"$OUTPUT_PATH/dialogSort";
i=1

for choice in $choices ;
do
	echo -n $choice >>"$OUTPUT_PATH/dialogSort";
	echo -n " " >>"$OUTPUT_PATH/dialogSort";
	echo $i >>"$OUTPUT_PATH/dialogSort";
	i=$[i+1]
done

while true ;
do
	test=$(dialog --stdout --clear --extra-button --extra-label "Move up" \
			--menu "Change the order of the include files if it matters:" 40 60 60 \
			--file "$OUTPUT_PATH/dialogSort" >"$OUTPUT_PATH/selection")
    
	# If move-up button was not clicked, move forward
	retval=$?
	if [ $retval -ne 3 ] ;
	then
		break;
	fi

	# Reorder the dialogSort
	cp "$OUTPUT_PATH/dialogSort" "$OUTPUT_PATH/copy";
	cat "$OUTPUT_PATH/selection" >"$OUTPUT_PATH/dialogSort";
	echo " 1" >>"$OUTPUT_PATH/dialogSort";
	cp "$OUTPUT_PATH/dialogSort" "$OUTPUT_PATH/firstline";
	cat "$OUTPUT_PATH/copy" >>"$OUTPUT_PATH/dialogSort";

	cat "$OUTPUT_PATH/dialogSort" \
		|grep -v -f "$OUTPUT_PATH/selection" \
		>>"$OUTPUT_PATH/firstline";

	cat "$OUTPUT_PATH/firstline" >"$OUTPUT_PATH/dialogSort";
	rm "$OUTPUT_PATH/firstline";
	rm "$OUTPUT_PATH/copy";
done

rm "$OUTPUT_PATH/selection";

# If cancel was pressed
if [ $retval -eq 1 ] ;
then
	rm "$OUTPUT_PATH/dialogSort";
	echo "Canceled";
	exit;
fi

# Remove numbers that was needed for the dialogSort
cat "$OUTPUT_PATH/dialogSort" |awk -F " " '{print $1}' >"$OUTPUT_PATH/selections";
rm "$OUTPUT_PATH/dialogSort";

echo "Building an Arduino debug file of the selected libraries...";

echo '/**********************' >>$OUTPUT_FILE;
echo ' * LIB HEADER FILES   *' >>$OUTPUT_FILE;
echo ' *********************/' >>$OUTPUT_FILE;

# Add header files on top of the file
for choice in `cat "$OUTPUT_PATH/selections"` ;
do
	h_extension='.h';
	h_file=$choice$h_extension;
	
	file=`find $LIB_PATH -name $h_file`;
	if [ -n "$file" ] ;
	then
		overwrittenLibraries="$overwrittenLibraries $choice";
		
		echo "Parsing $h_file...";
		cat $file >>$OUTPUT_FILE;
		echo '' >>$OUTPUT_FILE;
	else
		echo "Couldn't parse file: $h_file";
	fi
done

echo '/**********************' >>$OUTPUT_FILE;
echo ' * LIB SOURCE FILES   *' >>$OUTPUT_FILE;
echo ' *********************/' >>$OUTPUT_FILE;

# Add source files next
for choice in `cat "$OUTPUT_PATH/selections"` ;
do
	cpp_extension='.cpp';
	cpp_file=$choice$cpp_extension;
	
	file=`find $LIB_PATH -name $cpp_file`;
	if [ -n "$file" ] ;
	then
		echo "Parsing $cpp_file...";
		cat $file >>$OUTPUT_FILE;
		echo '' >>$OUTPUT_FILE;
	else
		echo "Couldn't parse file: $cpp_file";
	fi
done  

echo '/**********************' >>$OUTPUT_FILE;
echo ' * APPLICATION        *' >>$OUTPUT_FILE;
echo ' *********************/' >>$OUTPUT_FILE;

cat $INPUT_FILE >>$OUTPUT_FILE;

# Remove includes of libraries that are overwritten by the debug application
for lib in $overwrittenLibraries ;
do
	sed -i -- 's|^#include.\+'"$lib"'.\+||g' "$OUTPUT_FILE";
done

# Copy the outputfile and reorder it
cp "$OUTPUT_FILE" "$OUTPUT_PATH/copy.ino";

# Overwrite the outputfile
echo -n "// file: " >$OUTPUT_FILE;
echo `realpath $OUTPUT_FILE` |sed 's/.\+\///g' >>$OUTPUT_FILE;
echo "// This file is created by ArduinoDebugFileCreator at " >>$OUTPUT_FILE;
echo -n "// " >>$OUTPUT_FILE; 
date >>$OUTPUT_FILE;
echo '' >>$OUTPUT_FILE;

echo '/**********************' >>$OUTPUT_FILE;
echo ' * EXTERNAL LIBRARIES *' >>$OUTPUT_FILE;
echo ' *********************/' >>$OUTPUT_FILE;

# Replace include files to the outputfile
cat "$OUTPUT_PATH/copy.ino" \
	|grep "#include" \
	|sed 's/\(.\+["<]\)\(.\+[">]\)\(.*\)/\1\2/g' \
	>>"$OUTPUT_PATH/includes";

sort "$OUTPUT_PATH/includes" |uniq >"$OUTPUT_PATH/sortedIncludes";
cat "$OUTPUT_PATH/sortedIncludes" >>"$OUTPUT_FILE";
echo '' >>$OUTPUT_FILE;

# Remove include files from copy.ino
sed -i -- 's|^#include.\+||g' "$OUTPUT_PATH/copy.ino";

# Replace outputfile with the copy
cat "$OUTPUT_PATH/copy.ino" >>"$OUTPUT_FILE"

rm "$OUTPUT_PATH/copy.ino";
rm "$OUTPUT_PATH/includes";
rm "$OUTPUT_PATH/sortedIncludes";
rm "$OUTPUT_PATH/selections";

echo "Done." 
echo "Debug file can be found from $OUTPUT_FILE";
