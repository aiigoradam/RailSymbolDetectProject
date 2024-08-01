classdef SymbolDetector
    properties
        Detector % Object for the pretrained detector
        MaxProcessWidthFactor = 0.85 % Factor to exclude tiles in the legend area
    end

    methods
        function obj = SymbolDetector(detectorPath, maxProcessWidthFactor)
            % Constructor for the SymbolDetector class
            % detectorPath - Path to the pretrained detector file
            % maxProcessWidthFactor - Optional factor to adjust processing width

            if nargin >= 1 && ~isempty(detectorPath)
                detectorData = load(detectorPath);
                obj.Detector = detectorData.detector;
            end

            if nargin >= 2 && ~isempty(maxProcessWidthFactor)
                obj.MaxProcessWidthFactor = maxProcessWidthFactor;
            end
        end

        function results = detectSymbols(obj, tiles, tilePositions, fullImageSize)
            % Detect symbols within each tile and store global positions
            results = struct('BoundingBoxes', {}, 'Labels', {}, 'Scores', {}, 'TilePosition', {});
            maxProcessWidth = fullImageSize * obj.MaxProcessWidthFactor;

            for i = 1:numel(tiles)  % Retrieve the current tile's image and its position
                tileImage = tiles{i};  % The image data for the current tile
                tilePos = tilePositions(i, :); % [x, y] position of the tile's top-left corner

                if tilePos(1) > maxProcessWidth
                    continue; % Skip tiles in the legend area
                end

                % Detect symbols within the current tile using a pretrained detector
                [bboxes, scores, labels] = detect(obj.Detector, tileImage);
                
                % Process each detected symbol in the current tile
                for j = 1:size(bboxes, 1)
                    % Calculate global bounding box position
                    globalBbox = bboxes(j, :) + [tilePos(1), tilePos(2), 0, 0];
                    % Store the results along with scores
                    results(end+1) = struct('BoundingBoxes', globalBbox, ...
                        'Scores', scores(j), ...
                        'Labels', labels(j), ...
                        'TilePosition', tilePos);
                end
            end
        end

        function finalResults = applyNMS(~, results, overlapThreshold)
            %   applies a modified Non-Maximum Suppression that averages overlapping bounding boxes.
            %   results - A struct array with fields 'BoundingBoxes', 'Scores', 'Labels', and optionally 'TilePosition'.
            %   overlapThreshold - The threshold for overlap in NMS.

            % Validate input arguments
            narginchk(2, 3);
            % Set default overlapThreshold if not specified
            if nargin < 3
                overlapThreshold = 0.5; % Default overlap threshold if not specified
            end

            % Extract bounding boxes and scores from the results struct
            bboxes = vertcat(results.BoundingBoxes);
            scores = [results.Scores]';

            % Apply traditional NMS to get indices of boxes to keep
            [~, ~, indices] = selectStrongestBbox(bboxes, scores, 'OverlapThreshold', overlapThreshold);

            % Initialize finalResults
            finalResults = struct('BoundingBoxes', {}, 'Scores', {}, 'Labels', {}, 'TilePosition', {});

            % Loop through each set of overlapping boxes
            for i = 1:length(indices)
                % Find all boxes that overlap with the box with the highest score
                currentBox = bboxes(indices(i), :);
                overlapIdx = bboxOverlapRatio(currentBox, bboxes) > overlapThreshold;

                % Calculate the weighted average of the bounding box coordinates
                overlapBoxes = bboxes(overlapIdx, :);
                overlapScores = scores(overlapIdx);
                weightedSum = sum(overlapBoxes .* overlapScores, 1);
                weightedAverageBox = weightedSum / sum(overlapScores);

                % Create a new result entry with the averaged bounding box
                newResult.BoundingBoxes = weightedAverageBox;
                newResult.Scores = max(overlapScores); % Keep the highest score
                newResult.Labels = results(indices(i)).Labels; % Keep the label of the highest score
                newResult.TilePosition = results(indices(i)).TilePosition; % Keep the tile position of the highest score

                finalResults = [finalResults; newResult];
            end
        end
    end
end