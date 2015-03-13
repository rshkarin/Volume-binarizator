// Volume binarizator
// Roman Shkarin

macro "Binarize volume" {
	requires("1.49h")
	
	var inputPath = "D:\\Roman\\XRegio\\Medaka";
	var outputPath = "D:\\Roman\\XRegio\\Segmentations";
	
	var fishScale = "x2";
	var fishPrefix = "fish";
	var fileExt = ".raw";
	var filterSize = 5;
	var sliceNoiseThreshold = 5; //in percentage
	
	//var fishNumbers = newArray("200","202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245","A15");
	var fishNumbers = newArray("200","202");
	var medianFilteringFlag = false;
	
	setBatchMode(true);
	process(inputPath, outputPath, fishScale, fishPrefix, fileExt, sliceNoiseThreshold, fishNumbers);
	setBatchMode(false);
}

function process(inputPath, outputPath, fishScale, fishPrefix, fileExt, sliceNoiseThreshold, fishNumbers) {
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
			
		//Prethreshold with Otsu
		run("Duplicate...", "duplicate");
		duplicatedStackId = getImageID();
		selectImage(duplicatedStackId);
		run("Auto Threshold", "method=Otsu ignore_black white stack");

		//Detect eyes region
		run("Invert", "stack");
		run("Set Measurements...", "min shape area_fraction stack limit redirect=None decimal=3");
		run("Analyze Particles...", "size=2500-Infinity circularity=0.8-1.00 show=Nothing exclude clear stack");
		eyesRange = getSliceRangeOfEyes();
		selectImage(duplicatedStackId);
		close();
		
		Array.print(eyesRange);

		//Create new stack
		sliceOffset = floor(volSize[2]*0.05);
		
		newImage("segmented_" + currentFileNameNoExt, toString(colorDepth) + "-bit grayscale-mode", volSize[0], volSize[1], 1, volSize[2] + sliceOffset*2, 1);
		newStackId = getImageID();
		
		for (sliceIdx = 1; sliceIdx <= volSize[2]; sliceIdx++) {
 			//Update progress
 			showProgress((sliceIdx - 1) / volSize[2]);

			//Process original data
			selectImage(stackId);
 			setSlice(sliceIdx);

 			//Threshold eyes with special method
 			if (checkInRange(sliceIdx - 1, eyesRange)) {
 				run("Auto Threshold", "method=Li white");
 			}
 			else {
 				run("Auto Threshold", "method=Otsu white");
 			}
			
 			//Duplicate to check the noise level
			run("Duplicate...", "title=test_duplicated_" + currentFileNameNoExt);
 			testDuplicatedSliceId = getImageID();
			selectImage(testDuplicatedSliceId);
			
			//Increase noise if presented
			run("Options...", "iterations=4 count=1 black pad edm=Overwrite do=Dilate");
			getHistogram(values, binCounts, numBins);
			selectImage(testDuplicatedSliceId);
			close();
			
			if ((binCounts[values[0]] < binCounts[values[numBins - 1]]) && checkInBeginningOrEnd(sliceIdx, volSize[2], sliceNoiseThreshold)) {
				continue;
			}

			showText("Volume: " + fishPrefix + fishNumbers[i] + " | Slice " +  toString(sliceIdx) + "/" + toString(volSize[2]) + " is being processed");

			//Duplicate and process 
			selectImage(stackId);
			setSlice(sliceIdx);
 			run("Duplicate...", "title=duplicated_" + currentFileNameNoExt);
 			duplicatedSliceId = getImageID();
 			
 			//Add space on corners
			run("Canvas Size...",
			"width=" + toString(volSize[0] + floor(volSize[0] * 0.1)) +
			" height=" + toString(volSize[1] + floor(volSize[1] * 0.1)) +
			" position=Center zero");
			
 			run("Options...", "iterations=4 count=1 black pad edm=Overwrite do=Close");
			run("Fill Holes");
			
 			//Copy to new stack
			run("Select All");
			run("Copy");
			selectImage(newStackId);
			setSlice(sliceIdx + sliceOffset);
			run("Paste");

			selectImage(duplicatedSliceId);
			close();
		}
		
		selectImage(newStackId);

		//Update sizes
		volSize[0] = getWidth();
		volSize[1] = getHeight();
		volSize[2] = nSlices;

		run("Reslice [/]...", "output=1.000 start=Top avoid");
		reslicedStackTopId = getImageID();
		selectImage(reslicedStackTopId);
		run("Options...", "iterations=2 count=1 black pad edm=Overwrite do=Close stack");
		run("Fill Holes", "stack");
		
		run("Reslice [/]...", "output=1.000 start=Right rotate avoid");
		reslicedStackRightId = getImageID();
		selectImage(reslicedStackTopId);
		close();
		selectImage(reslicedStackRightId);
		run("Options...", "iterations=2 count=1 black pad edm=Overwrite do=Close stack");
		run("Fill Holes", "stack");
		
		run("Reslice [/]...", "output=1.000 start=Top rotate avoid");
		reslicedStackTop2Id = getImageID();
		selectImage(reslicedStackRightId);
		close();
		selectImage(reslicedStackTop2Id);
		run("Flip Horizontally", "stack");
		
		//Filter with 3D Median
		if (medianFilteringFlag) {
			run("Median 3D...", "x=" + toString(filterSize) + " y=" + toString(filterSize) + " z=" + toString(filterSize));
		}
		
		//Save as tiff stack
		saveDataAsTiffStack(outputPath, fishPrefix, fishNumbers[i], volSize, colorDepth, fishPrefix);

		//Close
		//selectImage(reslicedStackTop2Id);
		//close();
		close("*");
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

function saveDataAsTiffStack(outputPath, fishPrefix, fishNumber, volSize, colorDepth, fishPrefix) {
	savePath = outputPath + File.separator + fishPrefix + fishNumber;
	
	if (!File.exists(savePath)) {
		File.makeDirectory(savePath);
	} 

	saveAs("Tiff", savePath + File.separator + "segmented_" + fishPrefix + fishNumber + "_" + 
				   toString(colorDepth) + "bit_" + toString(volSize[0]) + "x" + toString(volSize[1]) + "x" + toString(volSize[2]) + ".tif");
}

function getSliceRangeOfEyes() {
	allIndicies = newArray();
	actualIndicies = newArray();
	step = 25;
	
	epsilon = 10;
	
	for (i = 0; i < nResults; i++) {
		allIndicies = Array.concat(allIndicies, parseInt(getResult("Slice", i)));
	}

	Array.print(allIndicies);

	for (i = 0; i < nResults; i++) {
		if (i < nResults - step) {
			localWindow = newArray();
			
			for (j = i + 1; j < i + step; j++) {
				localWindow = Array.concat(localWindow, allIndicies[j]);
			}
			Array.getStatistics(localWindow, localMin, localMax, localMean, localStd);

			if (abs(allIndicies[i] - localMean) > epsilon) {
				allIndicies[i] = 0;
			}
		}
	}

	Array.print(allIndicies);

	for (i = 0; i < nResults; i++) {
		if (allIndicies[i] > 0) {
			actualIndicies = Array.concat(actualIndicies, allIndicies[i]);
		}
	}
	
	Array.print(actualIndicies);
	
	Array.getStatistics(actualIndicies, min, max, mean, std);
	
	return newArray(min, max);
}

function checkInRange(index, array) {
	if (index >= array[0] && index <= array[1]) {
		return true;
	}

	return false;
}

function checkInBeginningOrEnd(index, sliceNum, sliceThreshold) {
	numSlicesThreshold = (sliceNum/100)*sliceThreshold;
	if ((index >= 1 && index <= numSlicesThreshold) ||
		(index >= (sliceNum - numSlicesThreshold) && index <= sliceNum)) {	
		return true;
	}
	else {
		return false;
	}
}
