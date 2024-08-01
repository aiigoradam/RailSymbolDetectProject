function ExportToExcel(dataTable, excelFilename, imageFolderPath)
    % Sort the dataTable by the 'Name' column
    sortedData = sortrows(dataTable, 'Name');

    % Export the sorted table to Excel
    writetable(sortedData, excelFilename, 'Sheet', 1);

    % Start an ActiveX server to interact with Excel
    ExcelApp = actxserver('Excel.Application');
    Workbook = ExcelApp.Workbooks.Open(fullfile(pwd, excelFilename));
    Sheet = Workbook.Sheets.Item(1); % Assumes data is in the first sheet
    % ExcelApp.Visible = true; % Make Excel visible to see the operations

    % Loop over each entry in the table to insert and resize images individually
    for i = 1:height(sortedData)
        ImageFileName = fullfile(imageFolderPath, [sortedData.Name{i}, '.png']);
        cellRef = ['A', num2str(i+1)]; % Assuming images start from row 2

        % Insert the image at an arbitrary position
        Picture = Sheet.Shapes.AddPicture(ImageFileName, 0, 1, 0, 0, -1, -1);

        % Calculate and adjust the aspect ratio of the image
        adjustImageAspectRatios(Picture, Sheet, cellRef);
    end

    % Save and close the workbook
    Workbook.Save();
    Workbook.Close();
    ExcelApp.Quit();
    release(ExcelApp);
end

function adjustImageAspectRatios(Picture, Sheet, cellRef)
    % Calculate the aspect ratio of the image
    picWidth = Picture.Width;
    picHeight = Picture.Height;
    picAspectRatio = picWidth / picHeight;

    % Get the target cell's dimensions
    Range = Sheet.Range(cellRef);
    cellLeft = Range.Left;
    cellTop = Range.Top;
    cellWidth = Range.Width;
    cellHeight = Range.Height;
    cellAspectRatio = cellWidth / cellHeight;

    % Determine the size to scale the image based on aspect ratio comparison
    if picAspectRatio > cellAspectRatio
        newWidth = cellWidth;
        newHeight = newWidth / picAspectRatio;
    else
        newHeight = cellHeight;
        newWidth = newHeight * picAspectRatio;
    end

    % Set the new size and position of the image
    Picture.LockAspectRatio = true; % Ensure aspect ratio is maintained
    Picture.Width = newWidth;
    Picture.Height = newHeight;
    Picture.Left = cellLeft + (cellWidth - newWidth) / 2; % Center horizontally
    Picture.Top = cellTop + (cellHeight - newHeight) / 2; % Center vertically
end
