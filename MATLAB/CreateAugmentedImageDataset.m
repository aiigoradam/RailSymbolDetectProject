function dsExpanded = CreateAugmentedImageDataset(datastore, numAugmentations)
    % Check the number of augmentations parameter
    if nargin < 2
        numAugmentations = 4; % Default to 4 augmentations if not specified
    end
    
    % Ensure the 'ImagesTrainSet' directory exists in the current working directory
    outputFolder = fullfile(pwd, 'ImagesTrainSet');
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder); % Create the directory if it doesn't exist
    else
        % Clear the directory of existing files if it already exists
        delete(fullfile(outputFolder, '*'));
    end
    
    % Read from datastore and store original images and annotations
    reset(datastore); % Reset the datastore to the beginning
    originalData = readall(datastore); % Read all data from the datastore
    
    % Initialize cell arrays to hold file paths and annotations
    imageFiles = cell(size(originalData, 1) * (numAugmentations + 1), 1);
    allBboxes = cell(size(imageFiles));
    allLabels = cell(size(imageFiles));
    
    % Apply augmentations to each image and save the results
    for idx = 1:size(originalData, 1)
        originalImage = originalData{idx, 1};
        originalBoxes = originalData{idx, 2};
        originalLabels = originalData{idx, 3};
        
        % Define file path for the original image
        originalFilePath = fullfile(outputFolder, sprintf('image_%d_original.jpg', idx));
        imwrite(originalImage, originalFilePath); % Save the original image
        
        % Store the original image details
        imageIdx = (idx - 1) * (numAugmentations + 1) + 1;
        imageFiles{imageIdx} = originalFilePath;
        allBboxes{imageIdx} = originalBoxes;
        allLabels{imageIdx} = originalLabels;
        
        % Generate and save augmented images
        for augIdx = 1:numAugmentations
            augmentedResult = augmentData({originalImage, originalBoxes, originalLabels});
            augmentedImage = augmentedResult{1};
            augmentedBoxes = augmentedResult{2};
            augmentedLabels = augmentedResult{3};
            
            % Define file path for the augmented image
            augmentedFilePath = fullfile(outputFolder, sprintf('image_%d_augmented_%d.jpg', idx, augIdx));
            
            if ~isempty(augmentedBoxes)
                imwrite(augmentedImage, augmentedFilePath); % Save the augmented image
                imageFiles{imageIdx + augIdx} = augmentedFilePath;
                allBboxes{imageIdx + augIdx} = augmentedBoxes;
                allLabels{imageIdx + augIdx} = augmentedLabels;
            else
                imageFiles{imageIdx + augIdx} = [];
                allBboxes{imageIdx + augIdx} = [];
                allLabels{imageIdx + augIdx} = [];
            end
        end
    end
    
    % Remove any empty cells caused by removed images
    imageFiles = imageFiles(~cellfun(@isempty, imageFiles));
    allBboxes = allBboxes(~cellfun(@isempty, allBboxes));
    allLabels = allLabels(~cellfun(@isempty, allLabels));
    
    % Create imageDatastore and boxLabelDatastore for the images and annotations
    imdsExpanded = imageDatastore(imageFiles);
    bboxesTable = table(allBboxes, allLabels, 'VariableNames', {'Boxes', 'Labels'});
    bldsExpanded = boxLabelDatastore(bboxesTable);
    
    % Combine imageDatastore and boxLabelDatastore into one datastore
    dsExpanded = combine(imdsExpanded, bldsExpanded);
end


function data = augmentData(A)
    % The augmentData function randomly applies flipping, rotation, scaling, and zooming
    % to pairs of images and bounding boxes. Boxes that get transformed outside
    % the bounds are clipped if the overlap is above 0.25.

    data = cell(size(A));
    for ii = 1:size(A,1)
        I = A{ii,1};
        bboxes = A{ii,2};
        labels = A{ii,3};
        sz = size(I);

        % Randomly choose to flip, rotate, or scale the image
        if rand < 0.5
            % Randomly choose a rotation angle between -42 to 42 degrees
            rotationAngle = (randi([-6, 6], 1) * 7); 

            % Calculate scaling factor to fit the rotated image into the original dimensions
            diagonal = sqrt(sz(1)^2 + sz(2)^2); 
            maxDim = max(sz(1), sz(2)); 
            scaleFactor = maxDim / diagonal; 

            % Define the rotation transformation matrix
            rotationMatrix = [cosd(rotationAngle), sind(rotationAngle), 0;
                             -sind(rotationAngle), cosd(rotationAngle), 0;
                              0,                   0,                  1];

            % Apply the scaling factor to the rotation matrix
            transformationMatrix = scaleFactor * rotationMatrix;

        elseif rand < 0.5
            % Random flip
            transformationMatrix = eye(3); 
            if rand < 0.5
                transformationMatrix(1,1) = -1; % Horizontal flip
            else
                transformationMatrix(2,2) = -1; % Vertical flip
            end

        else
            % Random scaling/zooming between 90% and 110%
            scaleFactor = 0.9 + rand * 0.2; % Uniform distribution between 0.9 and 1.1
            transformationMatrix = eye(3) * scaleFactor;
        end

        % Ensure the last column is [0; 0; 1]
        transformationMatrix(:,3) = [0; 0; 1];

        % Define the affine transformation
        tform = affine2d(transformationMatrix);

        % Determine output view so that the entire transformed image fits
        outputView = affineOutputView(sz(1:2), tform, 'BoundsStyle', 'CenterOutput');

        % Apply the combined transformations to the image
        I = imwarp(I, tform, 'OutputView', outputView);

        % Apply the same transformations to the bounding boxes
        [bboxes, indices] = bboxwarp(bboxes, tform, outputView, 'OverlapThreshold', 0.25);
        labels = labels(indices);

        % Return original data only when all boxes are removed by warping
        if isempty(indices)
            data(ii,:) = A(ii,:);
        else
            data(ii,:) = {I, bboxes, labels};
        end
    end
end
