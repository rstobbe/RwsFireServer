
%================================================================
%  TCP/IP Port Control
%================================================================

classdef RwsPortControl < handle
    
    properties (SetAccess = private) 
        port;
        ReconHandlerName;
        MetaData;
        FirstDataHeader;
        IdentifierLength;
        HeaderLength;
        TrajLength;
        DataLength;
        TotalLength;
        AcqsPerPortRead;
        AcqsPerImage;
        TotalAcqs;
        SampStart;
        SampEnd;
        NumCol;
        NumAverages;
        NumContrasts;
        NumPhases;
        NumRepititions;
        NumSets;
        NumSegments;
        RxChannels;
        TrajDims;
        TotalPortReads;
        TotalBlockReads;
        BlocksPerImage;
        ExpectedBytes;
        BufferReadNumber = 0;
        BaseSocket;
        SocketBufferSize = 100e7;               % higher - for image??        
        SocketInputStream;
        SocketDataInputStream;
        SocketOutputStream;
        PortDataSize;
        PortData;
        PortWait = 0;
        MaxPortWait = 0;
        MaxPortWaitAcq = 0;
        PortReadTime = 0;
        MaxPortReadTime = 0;
        DataBlockAcqStartNumber;
        DataBlockAcqStopNumber;
        DataAcqNumber;
        DataBlockNumber;
        DataBlockLength;
        DataBlockIds;
        DataBlockHeaders;
        DataBlock;
        CartInfo;
    end
    methods

%==================================================================
% Constructor
%==================================================================  
        function obj = RwsPortControl(port,log)
            import java.net.ServerSocket
            import java.io.*
            obj.port = port;
            obj.BaseSocket = ServerSocket(obj.port);
            obj.BaseSocket.setSoTimeout(0);                   % infinite timeout.  
        end
        
%==================================================================
% ConnectClient
%==================================================================          
        function ConnectClient(obj,log)
            Path = fileparts(mfilename('fullpath'));
            javaaddpath(Path);
            import java.net.ServerSocket
            import java.io.*
            OpenSocket = obj.BaseSocket.accept;
            OpenSocket.setSendBufferSize(obj.SocketBufferSize);            
            OpenSocket.setReceiveBufferSize(obj.SocketBufferSize);
            obj.SocketOutputStream = OpenSocket.getOutputStream;
            obj.SocketInputStream = OpenSocket.getInputStream;
            dInputStream = DataInputStream(obj.SocketInputStream);
            obj.SocketDataInputStream = DataReader(dInputStream);
        end
        
%==================================================================
% ReadPortMetaData
%==================================================================   
        function ReadPortMetaData(obj,log)
            
            %--------------------------------------------
            % Get Recon
            %--------------------------------------------
            Id = typecast(obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_MESSAGE_IDENTIFIER),'uint16');
            if Id ~= constants.MRD_MESSAGE_CONFIG_FILE
                error('fix ReadPortMetaData');
            end
            ReconHandlerNameBytes = obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_MESSAGE_CONFIGURATION_FILE);
            obj.ReconHandlerName = strtok(char(ReconHandlerNameBytes)',char(0));

            %--------------------------------------------
            % Get MetaData
            %--------------------------------------------
            Id = typecast(obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_MESSAGE_IDENTIFIER),'uint16');
            if Id ~= constants.MRD_MESSAGE_METADATA_XML_TEXT
                error('fix ReadPortMetaData');
            end            
            length = typecast(obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_MESSAGE_LENGTH),'uint32');
            MetaDataBytes = obj.SocketDataInputStream.readBuffer(length);
            MetaData0 = strtok(char(MetaDataBytes)',char(0));
            
            %--------------------------------------------
            % Siemens_to_ISMRMRD Fix 
            %--------------------------------------------
            if contains(MetaData0,'\n')                 
                MetaData1 = erase(MetaData0,'\n');      
                MetaData1 = erase(MetaData1,'\t');
                MetaData1 = MetaData1(3:end-1);
            else
                MetaData1 = MetaData0;
            end
            obj.MetaData = ismrmrd.xml.deserialize(MetaData1);   
            
            %--------------------------------------------
            % Get FirstDataHeader
            %--------------------------------------------
            Id = typecast(obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_MESSAGE_IDENTIFIER),'uint16');
            if Id ~= constants.MRD_MESSAGE_ISMRMRD_ACQUISITION
                error('fix ReadPortMetaData');
            end
            HeaderBytes0 = int8(obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_ACQUISITION_HEADER));
            HeaderBytes = typecast(HeaderBytes0,'uint8');
            obj.FirstDataHeader = ismrmrd.AcquisitionHeader(HeaderBytes);
           
            %--------------------------------------------
            % Initialize PortData Info
            %--------------------------------------------            
            obj.RxChannels = obj.FirstDataHeader.active_channels;
            obj.TrajDims = obj.FirstDataHeader.trajectory_dimensions;
            obj.IdentifierLength = constants.SIZEOF_MRD_MESSAGE_IDENTIFIER;
            obj.HeaderLength = constants.SIZEOF_MRD_ACQUISITION_HEADER;
            obj.TrajLength = double(obj.FirstDataHeader.number_of_samples) * double(obj.FirstDataHeader.trajectory_dimensions) * 4;
            obj.DataLength = double(obj.FirstDataHeader.number_of_samples) * double(obj.FirstDataHeader.active_channels) * 8;
            obj.TotalLength = obj.HeaderLength + obj.TrajLength + obj.DataLength + obj.IdentifierLength;
            
            %--------------------------------------------
            % Other Info
            %--------------------------------------------   
            obj.NumCol = obj.FirstDataHeader.number_of_samples;
            obj.NumAverages = obj.MetaData.encoding.encodingLimits.average.maximum + 1;
            obj.NumContrasts = obj.MetaData.encoding.encodingLimits.contrast.maximum + 1;
            obj.NumPhases = obj.MetaData.encoding.encodingLimits.phase.maximum + 1;
            obj.NumRepititions = obj.MetaData.encoding.encodingLimits.repetition.maximum + 1;
            obj.NumSets = obj.MetaData.encoding.encodingLimits.set.maximum + 1;
            obj.NumSegments = obj.MetaData.encoding.encodingLimits.segment.maximum + 1;
            obj.CartInfo.NumSlices = obj.MetaData.encoding.encodingLimits.slice.maximum + 1;
            obj.CartInfo.NumPe1Steps = obj.MetaData.encoding.encodingLimits.kspace_encoding_step_1.maximum + 1;
            obj.CartInfo.NumPe2Steps = obj.MetaData.encoding.encodingLimits.kspace_encoding_step_2.maximum + 1;  
        end
        
%==================================================================
% InitStitchPortControl
%==================================================================   
        function InitStitchPortControl(obj,PortUpdate,log)
            obj.AcqsPerPortRead = PortUpdate.AcqsPerPortRead;                       
            obj.AcqsPerImage = obj.CartInfo.NumPe1Steps;            % should include Dummy Acqs.
            if isfield(PortUpdate,'TotalAcqs')
                obj.TotalAcqs = PortUpdate.TotalAcqs;
            else
                obj.TotalAcqs = obj.NumAverages * obj.NumContrasts * obj.NumRepititions * obj.NumSets * obj.AcqsPerImage;
            end    
            obj.SampStart = PortUpdate.SampStart;
            obj.SampEnd = PortUpdate.SampEnd;
            obj.NumCol = PortUpdate.NumCol;            
            obj.PortDataSize = obj.AcqsPerPortRead * obj.TotalLength;
            obj.PortData = zeros(obj.PortDataSize,1);   
            obj.ExpectedBytes = obj.TotalAcqs*obj.TotalLength - (obj.IdentifierLength+obj.HeaderLength);
            obj.TotalPortReads = ceil(obj.TotalAcqs/obj.AcqsPerPortRead);
            obj.TotalBlockReads = obj.TotalPortReads;
            obj.BlocksPerImage = ceil(obj.AcqsPerImage/obj.AcqsPerPortRead);
            obj.DataBlockNumber = 0;
            obj.DataAcqNumber = 1;
            obj.DataBlockLength = obj.AcqsPerPortRead; 
            obj.DataBlock = zeros(obj.NumCol*2,obj.AcqsPerPortRead,obj.RxChannels,'single');
        end

%==================================================================
% InitCartPortControl
%==================================================================   
        function InitCartPortControl(obj,PortUpdate,log)
            obj.AcqsPerPortRead = PortUpdate.AcqsPerPortRead;
            if isfield(PortUpdate,'TotalAcqs')
                obj.TotalAcqs = PortUpdate.TotalAcqs;
            else
                obj.TotalAcqs = obj.NumAverages * obj.NumContrasts * obj.NumPhases * obj.NumRepititions * obj.NumSets * obj.NumSegments * obj.CartInfo.NumPe1Steps * obj.CartInfo.NumPe2Steps * obj.CartInfo.NumSlices;
            end
            obj.SampStart = obj.FirstDataHeader.discard_pre+1;
            obj.SampEnd = obj.SampStart-1 + obj.NumCol - obj.FirstDataHeader.discard_pre;
            obj.PortDataSize = obj.AcqsPerPortRead * obj.TotalLength;
            obj.PortData = zeros(obj.PortDataSize,1);   
            obj.ExpectedBytes = obj.TotalAcqs*obj.TotalLength - (obj.IdentifierLength+obj.HeaderLength);
            obj.TotalPortReads = ceil(obj.TotalAcqs/obj.AcqsPerPortRead);
            obj.TotalBlockReads = obj.TotalPortReads;
            obj.DataBlockNumber = 0;
            obj.DataAcqNumber = 1;
            obj.DataBlockLength = obj.AcqsPerPortRead; 
            obj.DataBlock = zeros(obj.NumCol*2,obj.AcqsPerPortRead,obj.RxChannels,'single');
        end        
        
%==================================================================
% ReadPortData
%==================================================================    
        function ReadPortData(obj,log)
            obj.BufferReadNumber = obj.BufferReadNumber + 1;
            tic
            while true
                DataAtPort = obj.SocketInputStream.available;
                if DataAtPort == obj.SocketBufferSize
                    log.error('SocketBufferSize must be increased');
                end
                if DataAtPort > obj.PortDataSize
                    break
                end
            end
            obj.PortWait(obj.BufferReadNumber) = toc;
            if obj.PortWait(obj.BufferReadNumber) > obj.MaxPortWait
                obj.MaxPortWait = obj.PortWait(obj.BufferReadNumber);
                obj.MaxPortWaitAcq = obj.BufferReadNumber;
            end 
            tic
            obj.PortData = obj.SocketDataInputStream.readBuffer(obj.PortDataSize);
            obj.PortReadTime(obj.BufferReadNumber) = toc;
            if obj.PortReadTime(obj.BufferReadNumber) > obj.MaxPortReadTime
                obj.MaxPortReadTime = obj.PortReadTime(obj.BufferReadNumber);
            end
            if obj.ExpectedBytes < obj.PortDataSize*(obj.BufferReadNumber + 1)
                obj.PortDataSize = obj.ExpectedBytes - (obj.PortDataSize*obj.BufferReadNumber);
            end
        end

%==================================================================
% CreateDataObject
%==================================================================          
        function CreateDataObject(obj,log)
            Ptr = 1;
            obj.DataBlockNumber = obj.DataBlockNumber + 1;
            obj.DataBlockAcqStartNumber = (obj.DataBlockNumber-1)*obj.AcqsPerPortRead + 1;
            obj.DataBlockAcqStopNumber = obj.DataBlockNumber*obj.AcqsPerPortRead;
            obj.DataBlockIds = zeros(1,obj.AcqsPerPortRead);
            obj.DataBlockHeaders = cell(1,obj.AcqsPerPortRead);
            warning('off');                 % for conversion of object to structure...                  
            for n = 1:obj.AcqsPerPortRead
                DataBytes = obj.PortData(Ptr:(Ptr+obj.DataLength-1));
                Data0 = typecast(DataBytes,'single'); 
                dims = [obj.FirstDataHeader.number_of_samples*2,obj.FirstDataHeader.active_channels];
                DataFull = reshape(Data0,dims);
                DataUsed = DataFull((obj.SampStart-1)*2+1:obj.SampEnd*2,:);
                obj.DataBlock(:,n,:) = DataUsed;
                if obj.DataAcqNumber == obj.TotalAcqs
                    obj.DataBlockAcqStopNumber = obj.TotalAcqs;
                    break
                end
                Ptr = Ptr + obj.DataLength;
                if Ptr+1 > length(obj.PortData)
                    error('Data Parsing Problem');
                end
                if Ptr > length(obj.PortData)
                    break
                end
                Id = typecast(obj.PortData(Ptr:(Ptr+obj.IdentifierLength-1)),'uint16');
                if Id ~= constants.MRD_MESSAGE_ISMRMRD_ACQUISITION
                    error('Data Parsing Problem');
                end
                obj.DataBlockIds(n) = Id;
                Ptr = Ptr + obj.IdentifierLength;
                HeaderBytes = obj.PortData(Ptr:(Ptr+obj.HeaderLength-1));
                Header = ismrmrd.AcquisitionHeader(typecast(HeaderBytes,'uint8'));
                obj.DataBlockHeaders{n} = Header;
                Ptr = Ptr + obj.HeaderLength; 
                obj.DataAcqNumber = obj.DataAcqNumber + 1;
            end
            warning('on');
        end

%==================================================================
% SendOneImage
%==================================================================         
        function SendOneImage(obj,Image,log)
            
            obj.SocketOutputStream.write(typecast(uint16(constants.MRD_MESSAGE_ISMRMRD_IMAGE),'uint8'),0,2); 
            HeaderBytes = Image.head_.toBytes();
            obj.SocketOutputStream.write(HeaderBytes,0,length(HeaderBytes));
            AttributeLengthBytes = typecast(uint64(length(Image.attribute_string_)),'uint8');
            obj.SocketOutputStream.write(AttributeLengthBytes,0,length(AttributeLengthBytes));
            AttributeStringBytes = uint8(Image.attribute_string_);
            obj.SocketOutputStream.write(AttributeStringBytes,0,length(AttributeStringBytes));
            DataBytes = typecast(reshape(Image.data_,[],1),'uint8'); 
            obj.SocketOutputStream.write(DataBytes,0,length(DataBytes));
            
        end

%==================================================================
% GetDataBlockIds
%==================================================================    
        function DataBlockIds = GetDataBlockIds(obj,log)
            DataBlockIds = obj.DataBlockIds;
        end  
        
%==================================================================
% GetDataBlockHeaders
%==================================================================    
        function DataBlockHeaders = GetDataBlockHeaders(obj,log)
            DataBlockHeaders = obj.DataBlockHeaders;
        end 
        
%==================================================================
% PortFinish
%==================================================================    
        function PortFinish(obj,log)
            obj.SendClose;
            obj.ClosePort;
        end           
        
%==================================================================
% SendClose
%==================================================================    
        function SendClose(obj,log)
            CloseMsg = typecast(uint16(constants.MRD_MESSAGE_CLOSE),'uint8');
            obj.SocketOutputStream.write(CloseMsg,0,2);
        end      
        
%==================================================================
% ClosePort
%==================================================================    
        function ClosePort(obj,log)
            obj.BaseSocket.close;
        end
    end  
end
