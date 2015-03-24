// Volume binarizator
// Roman Shkarin

macro "Binarize volume" {
	requires("1.49h")
	
	var inputPath = "D:\\Roman\\XRegio\\Medaka";
	var outputPath = "D:\\Roman\\XRegio\\Segmentations";
	var outputMedianPath = "D:\\Roman\\XRegio\\Segmentations_Median";


	//var inputPath = "/Users/Roman/Documents/test_data";
	//var outputPath = "/Users/Roman/Documents/test_segmentations";
	
	var fishScale = "x1";
	var fishPrefix = "fish";
	var fileExt = ".raw";
	var segmentedFishFileExt = ".tif";
	var method_name = "segmented";
	var filterSize = 5;
	var sliceNoiseThreshold = 2; //in percentage
	var sliceLocalNoiseThreshold = 5; //in percentage

	
	//var fishNumbers = newArray("200","202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245","A15");
	var fishNumbers = newArray("200");
	//var fishNumbers = newArray("200", "202","204","214","215","221","223","224","226","228","230","231","233","235","236","237","238","239","243","244","245","A15");
	
	var medianFilteringFlag = true;
	
	setBatchMode(true);
	
	process(inputPath, outputPath, fishScale, fishPrefix, fileExt, sliceNoiseThreshold, fishNumbers);
	
	if (medianFilteringFlag) {
		medianFiltering(outputPath, outputMedianPath, method_name, fishPrefix, segmentedFishFileExt, fishNumbers);
	}
	
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

      	printLogMessage("Binarizing started", currentPath + File.separator + currentFileName);

		currentFileNameNoExt = replace(currentFileName, fileExt, "");
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

		step=1;
		
		newImage("segmented_" + currentFileNameNoExt, toString(colorDepth) + "-bit grayscale-mode", volSize[0], volSize[1], 1, volSize[2], 1);
		newStackId = getImageID();
		
		for (sliceIdx = 1; sliceIdx <= volSize[2]; sliceIdx+=step) {
		//for (sliceIdx = 2800; sliceIdx <= 2850; sliceIdx+=step) {

 			//Update progress
 			showProgress(sliceIdx / volSize[2]);
 			showText("Volume: " + fishPrefix + fishNumbers[i] + " | Slice " +  toString(sliceIdx) + "/" + toString(volSize[2]) + " is being processed");

			//Process original data
			selectImage(stackId);
 			setSlice(sliceIdx);

 			//Duplicate to check the noise level
			run("Duplicate...", "title=test_duplicated_" + currentFileNameNoExt);
 			testDuplicatedSliceId = getImageID();
			selectImage(testDuplicatedSliceId);
			
			//Increase noise if presented
			run("Auto Threshold", "method=Otsu white");
			run("Options...", "iterations=10 count=1 black edm=Overwrite do=Dilate");
			selectImage(testDuplicatedSliceId);
			getHistogram(values, binCounts, numBins);
			close();

			if ((binCounts[values[0]] < binCounts[values[numBins - 1]]) && checkInBeginningOrEnd(sliceIdx, volSize[2], sliceNoiseThreshold)) {
				continue;
			}

			//Duplicate and process 
			selectImage(stackId);
			setSlice(sliceIdx);
			
 			//run("Duplicate...", "duplicate range=" + toString(sliceIdx - nearestSlices) + "-" + toString(sliceIdx + nearestSlices) + " title=duplicated_1" + currentFileNameNoExt);
 			run("Duplicate...", "title=duplicated_1" + currentFileNameNoExt);
 			duplicatedSliceId1 = getImageID();

 			selectImage(stackId);
 			//run("Duplicate...", "duplicate range=" + toString(sliceIdx - nearestSlices) + "-" + toString(sliceIdx + nearestSlices) + " title=duplicated_2" + currentFileNameNoExt);
 			run("Duplicate...", "title=duplicated_2" + currentFileNameNoExt);
 			duplicatedSliceId2 = getImageID();

 			//Add space on corners
 			/*
			run("Canvas Size...",
			"width=" + toString(volSize[0] + floor(volSize[0] * 0.1)) +
			" height=" + toString(volSize[1] + floor(volSize[1] * 0.1)) +
			" position=Center zero");
			*/
			
			
			/*
			run("Variance...", "radius=2");
			run("Non-local Means Denoising", "sigma=40");
			run("Auto Threshold", "method=Otsu white");
			run("Fill Holes");
			*/
			//Mask creating

			//Extraction sequence
			//run("Gaussian Blur...", "sigma=2");
			
			//run("Unsharp Mask...", "radius=1 mask=0.60");
			//run("Median...", "radius=2");
			//run("Variance...", "radius=1");
			//run("FeatureJ Edges", "compute smoothing=1 lower=[] higher=[]");
			//run("8-bit");
			//run("Variance...", "radius=1");   //204
			//run("Non-local Means Denoising", "sigma=30");
			//run("Variance...", "radius=2");   //204\
			//run("Variance...", "radius=1");   //204
			//run("Non-local Means Denoising", "sigma=50");
			//run("Variance...", "radius=1");   //202
			
			//run("Variance...", "radius=1");
			//run("Unsharp Mask...", "radius=1 mask=0.60");
			//run("Auto Threshold", "method=Otsu white");
			//run("Options...", "iterations=2 count=1 black edm=Overwrite do=Close");
			//run("Fill Holes");
			//run("Median...", "radius=5");
			//run("Options...", "iterations=2 count=1 black edm=Overwrite do=Erode");
			//run("Median...", "radius=5");

			//Second cosn
			/*
			selectImage(duplicatedSliceId1);
			run("Gaussian Blur...", "sigma=1");
			run("Variance...", "radius=3");
			run("Auto Threshold", "method=Li white");
			run("Options...", "iterations=6 count=1 black edm=Overwrite do=Close");
			run("Fill Holes");
			run("Median...", "radius=5");

			selectImage(duplicatedSliceId2);
			run("Auto Threshold", "method=Otsu white");
			run("Variance...", "radius=1");
			run("Options...", "iterations=5 count=1 black edm=Overwrite do=Close");
			run("Fill Holes");
			run("Median...", "radius=5");

			imageCalculator("OR", duplicatedSliceId1, duplicatedSliceId2);
			selectImage(duplicatedSliceId1);
		
			run("Median...", "radius=3");
			run("8-bit");
			*/

			//New way#1
			selectImage(duplicatedSliceId1);
			run("Auto Threshold", "method=Otsu white");

			selectImage(duplicatedSliceId2);
			run("Gaussian Blur...", "sigma=1");
			//run("Variance...", "radius=1");
			run("Find Edges");
			run("Auto Threshold", "method=Otsu white");

			//One more check
			run("Duplicate...", "title=duplicated_local_noise_" + currentFileNameNoExt);
 			duplicatedLocalNoiseSliceId = getImageID();
			run("Options...", "iterations=6 count=1 black edm=Overwrite do=Close");
			run("Fill Holes");
			getHistogram(values, binCounts, numBins);
			close();
			
			if ((binCounts[values[0]] < binCounts[values[numBins - 1]]) && checkInBeginningOrEnd(sliceIdx, volSize[2], sliceLocalNoiseThreshold)) {
				selectImage(duplicatedSliceId1);
			}
			else {
				imageCalculator("Add", duplicatedSliceId1, duplicatedSliceId2);
				selectImage(duplicatedSliceId1);
			}
			
			run("Options...", "iterations=6 count=1 black edm=Overwrite do=Close");
			run("Fill Holes");
			run("Median...", "radius=3");
			//run("Options...", "iterations=3 count=1 black edm=Overwrite do=Erode");

			//Way #2 (too slow)
			/*
			selectImage(duplicatedSliceId1);
			run("Auto Threshold", "method=Otsu white stack");

			selectImage(duplicatedSliceId2);
			run("Gaussian Blur...", "sigma=1 stack");
			run("Variance...", "radius=1 stack");
			run("Auto Threshold", "method=Otsu white stack");

			imageCalculator("Add stack", duplicatedSliceId1, duplicatedSliceId2);
			selectImage(duplicatedSliceId1);
			
			run("Options...", "iterations=5 count=1 black edm=Overwrite do=Close stack");
			run("Fill Holes", "stack");
			run("Median 3D...", "x=3 y=3 z=3");
			run("Options...", "iterations=1 count=1 black edm=Overwrite do=Erode stack");
			
			run("Z Project...", "projection=[Average Intensity]");
			averagedSliceId = getImageID();
			
			run("Auto Threshold", "method=Otsu white");
			run("Fill Holes");
			*/
			
 			//Copy to new stack
			run("Select All");
			run("Copy");
			selectImage(newStackId);
			setSlice(sliceIdx);

			run("Paste");

			selectImage(duplicatedSliceId2);
			close();
			selectImage(duplicatedSliceId1);
			close();
			//selectImage(averagedSliceId);
			//close();
		}
		
		selectImage(newStackId);
		
		//Save as tiff stack
		saveDataAsTiffStack(outputPath, "segmented", fishPrefix, fishNumbers[i], volSize, colorDepth);
		
		printLogMessage("Binarizing finished", currentPath + File.separator + currentFileName);
	
		close("*");
	}
	close("*");
}

function medianFiltering(inputPath, outputPath, method_name, fishPrefix, segmentedFishFileExt, fishNumbers) {
	for (i = 0; i < fishNumbers.length; i++) {
		currentPath = inputPath + File.separator + fishPrefix + fishNumbers[i];
		fileList = getFileList(currentPath);
		currentFileName = "";
	
		for (j = 0; j < fileList.length; j++) {
			fileName = fileList[j];

			if (startsWith(fileName, method_name + "_" + fishPrefix + fishNumbers[i]) &&  endsWith(fileName, segmentedFishFileExt)) {
				currentFileName = fileName;
				break;
			}
		}

		//Open data as a tiff stack
		open(currentPath + File.separator + currentFileName);
		segmentedStackId = getImageID();

		//Get stack info
		stackWidth = getWidth();
		stackHeight = getHeight();
		stackSlices = nSlices;
		volSize = newArray(stackWidth, stackHeight, stackSlices);
		colorDepth = bitDepth();

		printLogMessage("Median filtering started", currentPath + File.separator + currentFileName);

		//Filter with 3D Median
		run("Median 3D...", "x=" + toString(filterSize) + " y=" + toString(filterSize) + " z=" + toString(filterSize));

		printLogMessage("Median filtering finished", currentPath + File.separator + currentFileName);
		
		//Save as tiff stack
		saveDataAsTiffStack(outputPath, method_name + "_median", fishPrefix, fishNumbers[i], volSize, colorDepth);
		
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

function saveDataAsTiffStack(outputPath, method_name, fishPrefix, fishNumber, volSize, colorDepth) {
	savePath = outputPath + File.separator + fishPrefix + fishNumber;
	
	if (!File.exists(savePath)) {
		File.makeDirectory(savePath);
	} 

	saveAs("Tiff", savePath + File.separator + method_name + "_" + fishPrefix + fishNumber + "_" + 
				   toString(colorDepth) + "bit_" + toString(volSize[0]) + "x" + toString(volSize[1]) + "x" + toString(volSize[2]) + ".tif");
}

function getSliceRangeOfEyes() {
	if (!nResults) {
		return newArray();
	}
	
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

function printLogMessage(title, message) {
	getDateAndTime(year, month, week, day, hour, min, sec, msec);
    print(hour+":"+min+":"+sec+" -- " + title + ": ", message);	
}
