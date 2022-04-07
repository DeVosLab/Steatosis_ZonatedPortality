/*	_________________________________________________________________
 
  	Zonated_portality_measurement.ijm
	_________________________________________________________________
	
	Author: 			Winnok H. De Vos
	Date Created: 		June 17th, 2021
	Date Last Modified:	April 6th, 2022 

 	Title:
 	Zonated portality measurement
 	
 	Description: 
 	Macro written for Cedric Peleman (UAntwerpen) for teh analysis of steatosis in liver.
 	Calculates the intensity distribution of a hypoxia marker as a function fo the normalized distance to portal veins.

 	Change log:
 	22/06/21: adapted the portal vein selection to accomodate both multipoint and composite roi selections
	06/04/22: introduced a tissue and lipid vesicle detection macro
	_________________________________________________________________
*/

/*
 	***********************

	Variable initiation

	***********************
*/

//	String variables
var dir								= "";										//	directory
var micron							= getInfo("micrometer.abbreviation");		// 	micro symbol
var output_dir						= "";										//	dir for analysis output
var results							= "";										//	summarized results	

//	Number variables
var channels						= 4;										//	number of channels
var shrink_size						= 3;										//	factor to resize (shrink) input image

/*
 	***********************

		Macros

	***********************
*/

macro "AutoRun"
{
	set_options()
	erase(0);
}

macro "Open and convert Image Action Tool - C888 T5f16O"
{
	// open the image
	shrink_size = 2;
	setBatchMode(true);
	open("");
	raw_id = getImageID;
	raw_title = getTitle;
	selectImage(raw_id);
	// image loads as RGB stack so first flatten
	run("RGB Color"); 
	selectImage(raw_id); close;
	selectImage(raw_title+" (RGB)"); 
	rename("Input");
	id = getImageID;
	// resize according to a shrink factor
	old_width = getWidth;
	old_height = getHeight;
	new_width = round(old_width / shrink_size);
	new_height = round(old_height / shrink_size);
	run("Size...", "width="+new_width+" height="+new_height+" constrain average interpolation=Bilinear");
	// extract the relevant channel for measurement
	selectImage(id);
	title = getTitle;
	run("Colour Deconvolution", "vectors=[H&E 2] hide");
	selectImage(id); close;
	selectWindow(title+"-(Colour_3)");close;
	selectWindow(title+"-(Colour_1)");close;
	selectWindow(title+"-(Colour_2)"); 
	rename("Input"); 
	run("Grays");
	setBatchMode("exit and display");
}

macro "ROI Identification Action Tool - C888 T5f16R"
{
	// This macro identifies the tissue and lipid vescicle ROIs and also makes a difference ROI between both
	// it requires the "input" image as input
	max_lipid_size = 1000;
	min_lipid_size = 50;
	min_lipid_circ = 0.0;
	min_tissue_size = 100000;
	id = getImageID;
	width = getWidth;
	height = getHeight;
	roiManager("reset");
	run("Select None");
	setOption("BlackBackground", false);
	setBatchMode(true);
	selectImage(id);
	run("Duplicate...", "title=copy");
	copy_id = getImageID;
	selectImage(copy_id);
	run("Gaussian Blur...","sigma=1");
	//detect lipid vesicles
	setAutoThreshold("Triangle dark");
	run("Analyze Particles...", "size=min_lipid_size-max_lipid_size circularity=min_lipid_circ-1.00 show=Masks");
	selectImage("Mask of copy");
	mask_id = getImageID;
	selectImage(mask_id);
	run("Create Selection");
	roiManager("Add");
	selectImage(mask_id);close;
	selectImage(copy_id);
	// detect whole tissue
	run("Variance...", "radius=10");
	setAutoThreshold("Triangle dark");
	run("Analyze Particles...", "size="+min_tissue_size+"-Infinity include add");
	// filtered mask
	roiManager("select", newArray(0,1))
	roiManager("XOR");
	roiManager("Add");
	roiManager("select",0); 
	roiManager("rename", "Lipid Droplets");
	roiManager("select",1); 
	roiManager("rename", "Total Tissue");
	roiManager("select",2); 
	roiManager("rename", "Filtered Tissue");	
	selectImage(copy_id);close;
	roiManager("Deselect");
	setBatchMode("exit and display");
}

macro "Distance measurement Action Tool - C888 T5f16D"
{
	// This macro calculates a distance map based on a set of provided ROI sets
	// Currently it demands a set of two ROIs: 1. centres of the portal veins (multipoint roi) 
	// and 2. outline of the tissue (single freehand roi)
	// first check if roiset is present
	id = getImageID;
	width = getWidth;
	height = getHeight;
	n = roiManager("count");
	if(n<2)exit("Please assure that two ROIsets are provided, one for the portal vein centres and one for the tissue outline");
	setBatchMode(true);
	newImage("Portal", "8-bit black", width, height, 1); //distance map to portal veins
	portal_id = getImageID;
	// assuming first roi set are points this will be the edm wrt the centres of the portal veins
	selectImage(portal_id);
	roiManager("Select", 0); 
	if(Roi.getType == "point")roiManager("Draw");
	else if(Roi.getType == "composite")roiManager("Fill");
	run("Select None");
	setOption("BlackBackground", false);
	setThreshold(1, 255);
	run("Convert to Mask");
	run("Invert");
	// this will be the edm wrt the borders
	run("Duplicate...","title=Border");
	border_id = getImageID;
	// first edm for the portals
	selectImage(portal_id);
	run("Distance Map");
	selectImage(portal_id); close;
	selectWindow("EDM of Portal");
	edm_portal_id = getImageID;
	// now edm for the borders
	selectImage(border_id);	
	run("Invert");
	run("Voronoi");	
	selectImage(border_id); close;
	selectWindow("Voronoi of Border"); 
	rename("Border");
	getMinAndMax(min, max);
	setThreshold(min+1, max);
	run("Convert to Mask");
	roiManager("Select", 1); 
	run("Clear Outside");
	run("Select None");
	run("Invert");
	run("Distance Map");
	selectWindow("EDM of Border");
	edm_border_id = getImageID;
	imageCalculator("Add create 32-bit", "EDM of Portal","EDM of Border");
	imageCalculator("Divide create 32-bit", "EDM of Border","Result of EDM of Portal");
	selectImage(edm_border_id); close;
	selectImage(edm_portal_id); close;
	selectWindow("Border"); close;
	selectWindow("Result of EDM of Portal"); close;
	selectWindow("Result of EDM of Border");
	edm_id = getImageID; rename("EDM");
	run("16 colors");
	selectImage(edm_id);
	setBatchMode("exit and display");
}

function set_options()
{
	run("Options...", "iterations=1 count=1 edm=16-bit");
	run("Colors...", "foreground=white correct_background=black selection=yellow");
	run("Overlay Options...", "stroke=red width=1 fill=none");
	setBackgroundColor(0, 0, 0);
	setForegroundColor(255,255,255);
}

function erase(all)
{
	if(all){print("\\Clear");run("Close All");}
	run("Clear Results");
	roiManager("reset");
	run("Collect Garbage");
}