%================================================================
%  
%================================================================

classdef FormatImage

    properties (SetAccess = private)                    
    end
    methods 

       
%==================================================================
% Constructor
%==================================================================   
        function obj = FormatImage
            % 
        end                   
        
%==================================================================
% FormatImageFunction
%================================================================== 
        function FormatImageFunction(obj)
            
            image = ismrmrd.Image();
            
            %================================================    
            image.data_ = obj.image;                  % RWS - I made a change inside the 'Image' class
            %================================================

            % In MATLAB's ISMRMD toolbox, header information is not updated after setting image data
            image.head_.matrix_size(1) = uint16(size(img,1));
            image.head_.matrix_size(2) = uint16(size(img,2));
            image.head_.matrix_size(3) = uint16(size(img,3));
            image.head_.channels       = uint16(1);
            image.head_.data_type      = uint16(ismrmrd.ImageHeader.DATA_TYPE.SHORT);
            image.head_.image_index    = uint16(1);  % This field is mandatory

            % Set ISMRMRD Meta Attributes
            meta = ismrmrd.Meta();
            meta.DataRole     = 'Image';
            meta.WindowCenter = 16384;
            meta.WindowWidth  = 32768;

            image.attribute_string_ = serialize(meta);
            image.head_.attribute_string_len = uint32(length(image.attribute_string_));
        
        end    
    end
end