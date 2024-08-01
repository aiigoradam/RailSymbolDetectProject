classdef ImageSegmenter
    properties
        Image % Image to be segmented
        Overlap = 0.25 % Overlap ratio for image segmentation
        SegmentSize = [800, 800] % Size of each segment
        SaveFolderName = '' % Folder name for saving segments to disk
    end

    methods
        function obj = ImageSegmenter(image, overlap, segmentSize, saveFolderName)
            % Constructor method for creating an instance of the class
            obj.Image = image;
            if nargin >= 2 && ~isempty(overlap) % Check if the overlap ratio is provided and not empty
                obj.Overlap = overlap;
            end
            if nargin >= 3 && ~isempty(segmentSize) % Check if a custom segment size is provided and not empty
                obj.SegmentSize = segmentSize;
            end
            if nargin >= 4 % Check if a folder name for saving segments is provided
                obj.SaveFolderName = saveFolderName;
            end
        end

      function [tiles, tilePositions] = segmentImage(obj)
            % Read the input image
            [imgHeight, imgWidth, ~] = size(obj.Image);

            % Calculate overlap size in pixels and number of segments
            overlapSize = round(obj.SegmentSize .* obj.Overlap);
            numSegmentsX = ceil((imgWidth - overlapSize(2)) / (obj.SegmentSize(2) - overlapSize(2)));
            numSegmentsY = ceil((imgHeight - overlapSize(1)) / (obj.SegmentSize(1) - overlapSize(1)));

            % Initialize outputs
            tiles = cell(numSegmentsY * numSegmentsX, 1);
            tilePositions = zeros(numSegmentsY * numSegmentsX, 2);

            % Loop through and segment the image
            counter = 1;
            for y = 1:numSegmentsY
                for x = 1:numSegmentsX
                    startX = max(1, (x - 1) * (obj.SegmentSize(2) - overlapSize(2)) + 1);
                    startY = max(1, (y - 1) * (obj.SegmentSize(1) - overlapSize(1)) + 1);
                    endX = min(startX + obj.SegmentSize(2) - 1, imgWidth);
                    endY = min(startY + obj.SegmentSize(1) - 1, imgHeight);

                    % Extract the segment
                    segment = obj.Image(startY:endY, startX:endX, :);
                    tiles{counter} = segment;
                    tilePositions(counter, :) = [startX, startY];

                    counter = counter + 1;
                end
            end
        end

        function saveSegments(obj, tiles)
            % Ensure SaveFolderName is specified
            if isempty(obj.SaveFolderName)
                error('SaveFolderName must be specified to save segments to disk.');
            end
            
            % Prepare the directory for saving segments
            saveFolderPath = fullfile(pwd, obj.SaveFolderName);
            if ~exist(saveFolderPath, 'dir')
                mkdir(saveFolderPath);
            end

            % Save each segment to disk
            for i = 1:numel(tiles)
                segmentFilename = sprintf('Segment_%d.png', i);
                segmentFullPath = fullfile(saveFolderPath, segmentFilename);
                imwrite(tiles{i}, segmentFullPath);
            end
        end
    end
end