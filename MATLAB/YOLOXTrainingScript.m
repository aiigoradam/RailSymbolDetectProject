% Load Ground Truth data from the .mat file
data = load('gTruthTraining.mat');
gTruth = data.gTruth;

% Generate training data from the groundTruth object
[imds,blds] = objectDetectorTrainingData(gTruth);

% Combine image and box label datastores
ds = combine(imds, blds);

% Augment the data by using the transform function with custom preprocessing operations:
% Random horizontal/vertical flip, scale, rotation.
ds = CreateAugmentedImageDataset(ds, 10);

% Measure the distribution of class labels in the data set. 
labelCount = countEachLabel(ds.UnderlyingDatastores{1, 2});
disp(labelCount);

% Prior to partitioning the data, set the global random state to the 
% default state to ensure a higher reproducibility of results.
rng("default");

% Split the data set into training, validation, and test sets. 
% Because the total number of images is relatively small, allocate a 
% relatively large percentage (70%) of the data for training. 
% Allocate 15% for validation and the rest for testing.
numImages = ds.numpartitions;
numTrain = floor(0.7*numImages);
numVal = floor(0.15*numImages);

shuffledIndices = randperm(numImages);
dsTrain = subset(ds,shuffledIndices(1:numTrain));
dsVal = subset(ds,shuffledIndices(numTrain+1:numTrain+numVal));
dsTest = subset(ds,shuffledIndices(numTrain+numVal+1:end));

% Create the YOLOX object detector 
% Specify pretrained network
% Specify the class names and the network input size.
inputSize = [800 800 3];
classNames = categories(blds.LabelData{1,2}); % Get the names of the object classes as a categorical vector.
detectorIn = yoloxObjectDetector("tiny-coco", classNames, InputSize=inputSize);

% Specify network training options. 
% Train the object detector using the SGDM solver for a maximum of 100 epochs. 
% Specify the ValidationData name-value argument as the validation data. 
% Set OutputNetwork to "best-validation-loss" to obtain the network with the lowest 
% validation loss during training when the training finishes.
options = trainingOptions("sgdm", ...
    InitialLearnRate=5e-4, ...                       
    LearnRateSchedule="piecewise", ...                
    LearnRateDropFactor=0.99, ...         
    LearnRateDropPeriod=1, ...     
    MiniBatchSize=20, ...          
    MaxEpochs=100, ...
    BatchNormalizationStatistics="moving", ...
    ExecutionEnvironment="gpu", ...
    Shuffle="every-epoch", ...
    VerboseFrequency=10, ...
    ValidationFrequency=10, ... 
    ValidationData=dsVal, ...
    ResetInputNormalization=false, ...
    OutputNetwork="best-validation-loss", ...
    GradientThreshold=30, ... 
    Plots="training-progress", ...
    L2Regularization=5e-4);   

Train the detector 
[detector, info] = trainYOLOXObjectDetector(dsTrain, detectorIn, options,"FreezeSubNetwork","none");
 
% Save the trained detector
% save('trainedYOLOX2.mat', 'detector');

% Detect the bounding boxes for all test images.
detectionResults = detect(detector, dsTest);

% Obtain the metrics
metrics = evaluateObjectDetection(detectionResults,dsTest);

% Calculate the average precision score for each class. 
% Evaluate the trained object detector by measuring the average precision.
averagePrecision = cell2mat(metrics.ClassMetrics.AP);
classNames = replace(classNames,"_"," ");
table(classNames, averagePrecision)


