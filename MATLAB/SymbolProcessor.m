classdef SymbolProcessor
    properties
        FullImage
        Results
        Colors
        LabelsToNamesMap
    end

    methods
        function obj = SymbolProcessor(fullImage, results, colors, labelToNameMap)
            obj.FullImage = fullImage;
            obj.Results = results;
            obj.Colors = colors;
            obj.LabelsToNamesMap = labelToNameMap;
        end

        function visualizeDetectionResults(obj, fullImage)
            % Display the image
            imshow(fullImage);
            hold on;

            % Loop over the detection results
            for i = 1:length(obj.Results)
                bbox = obj.Results(i).BoundingBoxes;
                score = obj.Results(i).Scores;
                label = obj.Results(i).Labels;

                % Convert scores to strings and concatenate with labels for display
                labelsStr = string(label) + ": " + string(score);
                % Use showShape to display bounding boxes with labels and scores
                showShape("rectangle", bbox, 'Label', labelsStr, 'Color', 'yellow', 'LineWidth', 2);
            end

            hold off;
        end

        function displayCroppedSymbols(obj, scaleFactor)
            if nargin < 2 || isempty(scaleFactor)
                scaleFactor = 1.1; % Default scale factor
            end

            % Number of detected symbols
            numSymbols = numel(obj.Results);
            symbolsPerFigure = 20; % Symbols per figure (Adjustable)

            % Loop over each detected symbol
            for i = 1:numSymbols
                % Check if we need to create a new figure
                if mod(i-1, symbolsPerFigure) == 0
                    figure;
                    sgtitle(sprintf('Cropped Symbols - Figure %d', ceil(i / symbolsPerFigure)));
                end

                % Extract and scale the bounding box for the current symbol
                bbox = obj.Results(i).BoundingBoxes;
                scaledBbox = SymbolProcessor.scaleBoundingBox(bbox, scaleFactor, size(obj.FullImage));

                % Crop the symbol from the full image using the scaled bounding box
                croppedSymbol = imcrop(obj.FullImage, scaledBbox);

                % Determine the subplot position
                subplotPosition = mod(i-1, symbolsPerFigure) + 1;

                % Display the cropped symbol in a subplot
                subplot(4, 5, subplotPosition); % Arrange subplots in 4 rows and 5 columns
                imshow(croppedSymbol);

                % Prepare the title text with label, score, and color
                label = obj.Results(i).Labels;
                score = obj.Results(i).Scores; % Assuming 'Scores' field exists
                color = ''; % Initialize color text as empty
                if isfield(obj.Results(i), 'Color')
                    color = sprintf(', Color: %s', obj.Results(i).Color);
                end

                titleText = sprintf('%s (Score: %.2f)%s', label, score, color);

                title(titleText);
            end
        end

        function symbolsData = prepareSymbolsData(obj)
            % Initialize an empty table with the desired columns
            symbolsData = table([], [], [], [], 'VariableNames', {'Symbol', 'Name', 'Quantity', 'Color'});
            for i = 1:numel(obj.Results)
                symbolLabel = string(obj.Results(i).Labels);
                color = obj.Results(i).Color;

                % Use the mapping to get the corresponding name
                if isKey(obj.LabelsToNamesMap, symbolLabel)
                    imageName = obj.LabelsToNamesMap(symbolLabel);
                else
                    warning('Mapping for symbol %s not found.', symbolLabel);
                    imageName = symbolLabel; % Fallback to using the label directly
                end

                % Find if this symbol+color combination already exists in the table
                existingRow = find(strcmp(symbolsData.Name, imageName) & strcmp(symbolsData.Color, color));
                if isempty(existingRow)
                    % New symbol+color combination, add a new row
                    newRow = table({[]}, {imageName}, 1, {color}, ...
                        'VariableNames', {'Symbol', 'Name', 'Quantity', 'Color'});
                    symbolsData = [symbolsData; newRow];
                else
                    % Existing symbol+color, increment the quantity
                    symbolsData.Quantity(existingRow) = symbolsData.Quantity(existingRow) + 1;
                end
            end
            % Sort the symbolsData table by the Name column
            symbolsData = sortrows(symbolsData, 'Name');
        end

        function obj = detectPredominantColors(obj)
            % Iterate over each detection result (symbol) in the Results property
            for i = 1:numel(obj.Results)
                % Extract the bounding box for the current detection result
                bbox = obj.Results(i).BoundingBoxes;

                % Crop the symbol from the FullImage using the bounding box dimensions
                % This isolates the symbol for color analysis
                croppedSymbol = imcrop(obj.FullImage, bbox);

                % Call the static method detectPredominantColor to determine the
                % predominant color of the cropped symbol. This method compares the
                % symbol's color with predefined color ranges and selects the most
                % matching one.
                predominantColor = SymbolProcessor.detectPredominantColor(croppedSymbol, obj.Colors);

                % Update the current detection result with the identified predominant color
                obj.Results(i).Color = predominantColor;
            end
        end
    end

    methods (Static)
        function colorName = detectPredominantColor(image, colors)
            % Initialize color counts
            colorCounts = zeros(size(fieldnames(colors)));
            colorNames = fieldnames(colors);

            % Calculate color frequencies
            for idx = 1:length(colorNames)
                colorRange = colors.(colorNames{idx});
                lowerBound = colorRange(1, :); % Correct indexing for the lower bound
                upperBound = colorRange(2, :); % Correct indexing for the upper bound
                colorMask = (image(:,:,1) >= lowerBound(1) & image(:,:,1) <= upperBound(1)) & ...
                    (image(:,:,2) >= lowerBound(2) & image(:,:,2) <= upperBound(2)) & ...
                    (image(:,:,3) >= lowerBound(3) & image(:,:,3) <= upperBound(3));

                colorCounts(idx) = sum(colorMask(:));
            end

            % Sort colors by frequency
            [sortedCounts, sortIdx] = sort(colorCounts, 'descend');

            % Initially select the most dominant color
            colorName = colorNames{sortIdx(1)};

            % Check if the most dominant color is white or yellow, which could indicate background
            if strcmp(colorName, 'white') || strcmp(colorName, 'yellow')
                % Check the distribution to decide if it's actually the background
                if numel(sortedCounts) > 1
                    % Additional check to confirm if the dominant color is significantly more present
                    % This can be adjusted based on your specific criteria for "significantly more"
                    if sortedCounts(1) / sum(sortedCounts) > 0.5
                        % If the first color is overwhelmingly dominant, consider it as background
                        % and select the second most dominant color for the symbol
                        if numel(sortIdx) > 1  % Ensure there is a second color to select
                            colorName = colorNames{sortIdx(2)};
                        end
                    end
                end
            end
        end

        function scaledBbox = scaleBoundingBox(bbox, scaleFactor, imageSize)
            % Calculate the center of the bounding box
            center = bbox(1:2) + bbox(3:4) / 2;
            % Calculate the new size of the bounding box
            newSize = bbox(3:4) * scaleFactor;
            % Ensure the scaled bounding box does not exceed image boundaries
            scaledBbox = [max(center - newSize / 2, [1, 1]), newSize];
            scaledBbox(3:4) = min([imageSize(2) - scaledBbox(1), imageSize(1) - scaledBbox(2)], newSize);
        end
    end
end
