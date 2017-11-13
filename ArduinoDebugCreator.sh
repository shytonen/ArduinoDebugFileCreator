#! /bin/bash

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
	OUTPUT_FILE="$INPUT_PATH/arduino_debug.ino";

else
	OUTPUT_FILE=`realpath $3`;
fi

OUTPUT_PATH=`dirname $OUTPUT_FILE`

# Remove the file of includes if it exists
if [ -f includeFiles ] ;
then
	rm $OUTPUT_PATH/includeFiles;
fi

# Find header files from LIB_PATH
for file in $LIB_PATH/* ;
do
	# If the file is .cpp or .h file
	if [ -f $file ] && ! grep -q ".h$\|cpp$" $file ;
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
		>>$OUTPUT_PATH/includeFiles;
	fi
done

# Remove duplicate include files
sort $OUTPUT_PATH/includeFiles |uniq > $OUTPUT_PATH/sortedIncludes;
rm $OUTPUT_PATH/includeFiles

## TODO: Here could be a possibility to stop the program to correct the order of include files manually


# Create list of libraries for the dialog
liblist=""
n=1
for lib in $(cat $OUTPUT_PATH/sortedIncludes) ;
do
	## TODO: There could be some filter to ignore core libraries such as "Arduino.h"
	
	liblist="$liblist $lib $n off";
	n=$[n+1];
done

rm $OUTPUT_PATH/sortedIncludes;

# Start the dialog
choices=$(dialog --stdout --checklist 'Select libraries to debug:' 40 60 60 $liblist);

# Create the outputfile
echo -n "// file: " >$OUTPUT_FILE;
echo `realpath $OUTPUT_FILE` |sed 's/.\+\///g' >>$OUTPUT_FILE;
echo -n "// This file is created by ArduinoBug at " >>$OUTPUT_FILE;
date >>$OUTPUT_FILE;
echo '' >>$OUTPUT_FILE;

# Create new file of selections
if [ $? -eq 0 ] ;
then
	echo "Building an Arduino debug file of the selected libraries...";

	echo '/**********************' >>$OUTPUT_FILE;
	echo ' * LIB HEADER FILES   *' >>$OUTPUT_FILE;
	echo ' *********************/' >>$OUTPUT_FILE;
	
	# Add header files on top of the file
	for choice in $choices ;
	do
		h_extension='.h';
		h_file=$choice$h_extension;
		
		file=`find $LIB_PATH -name $h_file`;
		if [ -n "$file" ] ;
		then
			echo "Parsing $h_file...";
			cat $file >>$OUTPUT_FILE;
			echo '' >>$OUTPUT_FILE; echo '' >>$OUTPUT_FILE;
		else
			echo "Couldn't parse file: $h_file";
		fi
	done

	echo '/**********************' >>$OUTPUT_FILE;
	echo ' * LIB SOURCE FILES   *' >>$OUTPUT_FILE;
	echo ' *********************/' >>$OUTPUT_FILE;
	
	# Add source files next
	for choice in $choices ;
	do
		cpp_extension='.cpp';
		cpp_file=$choice$cpp_extension;
		
		file=`find $LIB_PATH -name $cpp_file`;
		if [ -n "$file" ] ;
		then
			echo "Parsing $cpp_file...";
			cat $file >>$OUTPUT_FILE;
			echo '' >>$OUTPUT_FILE; echo '' >>$OUTPUT_FILE;
		else
			echo "Couldn't parse file: $cpp_file";
		fi
	done  
else
	echo "Canceled";
fi

echo '/**********************' >>$OUTPUT_FILE;
echo ' * APPLICATION        *' >>$OUTPUT_FILE;
echo ' *********************/' >>$OUTPUT_FILE;

cat $INPUT_FILE >>$OUTPUT_FILE;

echo "Done." 
echo "Debug file can be found from $OUTPUT_FILE";