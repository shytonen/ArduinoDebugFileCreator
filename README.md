# ArduinoDebugFileCreator
Bash script that creates a debug file for arduino to debug self-written or third-party libraries.   

Usage:   
Give access rights: chmod u+x ./ArduinoDebugFileCreator   
Make sure dialog is installed on your linux.   
`./ArduinoDebugFileCreator program.ino library_dir [outputfile.ino]`   

Choose the libraries you want to debug. The script will combine the files inside the outputfile.ino.
![screenshot](screenshot.jpg "Script uses _dialog_ to select libraries")