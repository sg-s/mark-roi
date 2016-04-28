# markROI

Simple (<100 lines of code) UI to mark ROIs in image sequences written in MATLAB. This is built as a boilerplate for you to use in your own project.

## Features

* lets your mark ROIs
* works
* fast. loading images is instantaneous, no matter how big the files are

## Assumptions

* .mat files have a variable called "images"
* .mat files are v7.3 or later. use [convertMATFileTo73](https://github.com/sg-s/srinivas.gs_mtools/blob/master/src/file-tools/convertMATFileTo73.m) to convert your .mat files if needed. 
* You want to mark some "control" ROIs and some "test" ROIs

## Hacking 

The parts you probably want to change to re-purpose this to your use are as follows:

### loadFile

a function that loads the file. markROI uses `matfile` to speed up loading files, and the handle to the .mat file is stored in a variable called `m`. Look at all reads and writes from `m` and change as needed if your .mat files are structured differently from what is listed in the assumptions. 

### makeUI

this function makes the UI. You might want to add or remove `uicontrol` elements from this. All handles to UI elements are stored in the `handles` structure. 

## License 

GPLv3