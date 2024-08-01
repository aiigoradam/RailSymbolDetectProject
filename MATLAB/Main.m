% Initialize the PDF to Image Converter
pdfConverter = PDFImageConverter('Station 2.pdf');

% Convert the PDF to image
imageFileNames = pdfConverter.convertToImages();

% Load the full image
fullImage = imread(imageFileNames{1});
fullImageSize = size(fullImage, 2); % Calculate the size of the full image

% Initialize the Image Segmenter
segmenter = ImageSegmenter(fullImage, 0.25, [800,800]);

% Segment the image
% tiles - cell array containing the image data for each tile
% tilePositions - array containing the (x, y) positions of the top-left
% corner of each tile in the original image
[tiles, tilePositions] = segmenter.segmentImage();

% Initialize the Symbol Detector
detector = SymbolDetector('trainedYOLOX.mat', 0.85);

detectionResults = detector.detectSymbols(tiles, tilePositions, fullImageSize);
detectionResults = detector.applyNMS(detectionResults, 0.3);

% Define RGB color thresholds for basic colors
colors = struct(...
    'red', [200, 0, 0; 255, 100, 100], ...
    'green', [0, 200, 0; 100, 255, 100], ...
    'blue', [0, 0, 200; 100, 100, 255], ...
    'black', [0, 0, 0; 50, 50, 50], ...
    'yellow', [200, 200, 0; 255, 255, 150], ...
    'white', [200, 200, 200; 255, 255, 255]);

% Manual mapping between detected symbol labels and image file names
labelsToNamesMap = containers.Map({'AxleCounter', 'DistanceSignal', 'ExitSignalShunting', ...
    'HomeSignal', 'PointElectrical', 'ShuntingSignal'}, ...
    {'Axle Counter', 'Distance Signal', 'Exit Signal With Shunting', ...
    'Home Signal', 'Point Electrical', 'Shunting Signal'});

% Initialize the SymbolProcessor
processor = SymbolProcessor(fullImage, detectionResults, colors, labelsToNamesMap);

% Detect Predominant Colors in Detected Symbols
processor = processor.detectPredominantColors();

% Visualize Detection Results
processor.visualizeDetectionResults(fullImage);

% Prepare Symbols Data for Export or Analysis
symbolsData = processor.prepareSymbolsData();

% Display cropped symbols with an optional scale factor
processor.displayCroppedSymbols(1.2);

% Export data to Excel
excelFileName = 'SymbolsData.xlsx';
imageFolderPath = fullfile(pwd, 'LegendSymbols');
ExportToExcel(symbolsData, excelFileName, imageFolderPath);


