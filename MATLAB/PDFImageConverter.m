classdef PDFImageConverter
    properties
        PdfFileName % The name of the PDF file to convert
    end
    
    methods
        function obj = PDFImageConverter(pdfFileName)
            % Constructor method to create an instance of the class with the given PDF file name
            obj.PdfFileName = pdfFileName;
        end
        
        function imageFileNames = convertToImages(obj)
            % Convert the specified PDF file to images and return the paths of the converted images
            
            % Import necessary Java classes for PDFBox operations
            import org.apache.pdfbox.pdmodel.PDDocument;
            import org.apache.pdfbox.rendering.PDFRenderer;
            import org.apache.pdfbox.tools.imageio.ImageIOUtil;

            % Prepare the file and load the document
            filename = fullfile(pwd, obj.PdfFileName);
            [~, name, ~] = fileparts(filename); % Extract the name without extension
            jFile = java.io.File(filename);
            document = PDDocument.load(jFile);

            % Prepare the renderer
            pdfRenderer = PDFRenderer(document);
            pageCount = document.getNumberOfPages();
            
            % Initialize the output cell array to hold image filenames
            imageFileNames = cell(1, pageCount);

            % Loop through each page and convert it to an image
            for ii = 1:pageCount
                % Render the image using 300 DPI and RGB colors
                bim = pdfRenderer.renderImageWithDPI(ii - 1, 300, org.apache.pdfbox.rendering.ImageType.RGB);
                
                % Construct the output image filename
                imgFilename = sprintf('%s-Page%d.png', name, ii);
                
                % Save the rendered image to a file
                ImageIOUtil.writeImage(bim, imgFilename, 300);
                
                % Store the filename in the output array
                imageFileNames{ii} = imgFilename;
            end

            % Close the document
            document.close();
        end
    end
end
