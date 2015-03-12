// Volume binarizator
// Roman Shkarin

macro "Binarize volume" {
	requires("1.49h")
	
	var inputPath = "D:\\Roman\\XRegio\\Medaka";
	var outputPath = "D:\\Roman\\XRegio\\Segmentations";
	
	var fishScale = "x1";
	var fishPrefix = "fish";
	var fileExt = ".raw";
	var filterSize = 5;
	
	//var fishNumbers = newArray("200","202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245","A15");
	var fishNumbers = newArray("202");

	var levelSetsShapeEstimationFlag = false;
	var medianFilteringFlag = false;
	
	setBatchMode(true);
	process(inputPath, outputPath, fishScale, fishPrefix, fileExt, fishNumbers);
	setBatchMode(false);
}

function process(inputPath, outputPath, fishScale, fishPrefix, fileExt, fishNumbers) {
	for (i = 0; i < fishNumbers.length; i++) {
		currentPath = inputPath + File.separator + fishPrefix + fishNumbers[i] + File.separator +  fishScale;
		fileList = getFileList(currentPath);
		currentFileName = "";
	
		for (j = 0; j < fileList.length; j++) {
			fileName = fileList[j];
			
			if (startsWith(fileName, fishPrefix + fishNumbers[i]) &&  endsWith(fileName, fileExt)) {
				currentFileName = fileName;
				break;
			}
		}

		currentFileNameNoExt = replace(fileName, fileExt, "");
		colorDepth = getVolumeColorDepth(currentFileNameNoExt);
		volSize = getVolumeSizeFromFilename(currentFileNameNoExt, fileExt);
		numBins = pow(2, colorDepth);

		//Open data as stack
		run("Raw...", 
			"open=" + currentPath + File.separator + currentFileName +
			" image=[" + toString(colorDepth) + "-bit]" + 
			" width=" + toString(volSize[0]) +
			" height="+ toString(volSize[1]) +
			" number="+ toString(volSize[2]) +
			" offset=0" +
			" gap=0 little-endian");
		stackId = getImageID();

		//Add space on corners
		run("Canvas Size...",
			"width=" + toString(volSize[0] + floor(volSize[0] * 0.1)) +
			" height=" + toString(volSize[1] + floor(volSize[1] * 0.1)) +
			" position=Center zero");

		//Update sizes
		volSize[0] = getWidth();
		volSize[1] = getHeight();
		volSize[2] = nSlices;
			
		//Threshold with Otsu
		run("Auto Threshold", "method=Otsu ignore_black white stack");

		//Create new stack
		newImage("segmented_" + currentFileNameNoExt, toString(colorDepth) + "-bit grayscale-mode", volSize[0], volSize[1], 1, volSize[2], 1);
		newStackId = getImageID();
		
		//Select bounding box and segmented with Level Set
		for (sliceIdx = 1; sliceIdx <= volSize[2]; sliceIdx++) {
			selectImage(stackId);
 			setSlice(sliceIdx);
 			
			showProgress((sliceIdx - 1) / volSize[2]);

			run("Duplicate...", "title=test_duplicated_" + currentFileNameNoExt);
 			testDuplicatedSliceId = getImageID();
			selectImage(testDuplicatedSliceId);

			//Increase noise if presented
			run("Options...", "iterations=3 count=1 black edm=Overwrite do=Dilate");
			
			getHistogram(values, binCounts, numBins);
			if (binCounts[values[0]] < binCounts[values[numBins - 1]]) {
				continue;
			}	

			selectImage(stackId);
 			run("Duplicate...", "title=duplicated_" + currentFileNameNoExt);
 			duplicatedSliceId = getImageID();

 			if (levelSetsShapeEstimationFlag) {
	 			selectImage(duplicatedSliceId);
				run("Select Bounding Box (guess background color)");
	
				
				//showStatus("Slice " + toString(sliceIdx) + "/" + toString(volSize[2]) + " is being segmented");
				showText("Volume: " + fishPrefix + fishNumbers[i] + " | Slice " + toString(sliceIdx) + "/" + toString(volSize[2]) + " is being segmented");
				run("Level Sets", "method=[Active Contours] use_level_sets grey_value_threshold=255 distance_threshold=0.50 advection=1 propagation=1 curvature=8 grayscale=255 convergence=0.0005 region=inside");
				
				segmentedSliceId = getImageID();
				selectImage(segmentedSliceId);
 			}
 			else {
 				selectImage(duplicatedSliceId);
 			}
 			
			run("Select All");
			run("Copy");
			selectImage(newStackId);
			setSlice(sliceIdx);
			run("Paste");
		}
		
		selectImage(newStackId);

		if (medianFilteringFlag) {
			//Filter with 3D Median
			run("Median 3D...", "x=" + toString(filterSize) + " y=" + toString(filterSize) + " z=" + toString(filterSize));
		}
		
		//Save as tiff stack
		saveDataAsTiffStack(outputPath, fishPrefix, fishNumbers[i], currentFileNameNoExt);
	}

	close("*");
}

function getVolumeSizeFromFilename(fileName, fileExt) {
	tmp = split(fileName, "_");
	volInfo = split(tmp[2], "x");
	v1 = parseInt(volInfo[0]);
	v2 = parseInt(volInfo[1]);
	v3 = parseInt(volInfo[2]);
	return newArray(v1, v2, v3);
}

function getVolumeColorDepth(fileName) {
	colorDepth = split(fileName, "_");
	colorDepth = replace(colorDepth[1], "bit", "");
	return parseInt(colorDepth);
}

function saveDataAsTiffStack(outputPath, fishPrefix, fishNumber, currentFileName) {
	savePath = outputPath + File.separator + fishPrefix + fishNumber;
	
	if (!File.exists(savePath)) {
		File.makeDirectory(savePath);
	} 

	saveAs("Tiff", savePath + File.separator + "segmented_" + currentFileName + ".tif");
}