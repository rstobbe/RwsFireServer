
%================================================================
%  TCP/IP Port Control
%================================================================

classdef RwsPortControl < handle
    
    properties (SetAccess = private) 
        ReconType;
        MetaData;
        DataHeader;
        IdentifierLength;
        HeaderLength;
        TrajLength;
        DataLength;
        TotalLength;
        AcqsPerPortRead;
        TotalAcqs;
        TotalPortReads;
        ExpectedBytes;
        BufferReadNumber = 0;
        BaseSocket;
        SocketBufferSize = 100e6;               % higher - for image??        
        SocketInputStream;
        SocketDataInputStream;
        SocketOutputStream;
        PortDataSizeApprox = 20e6;
        PortDataSize;
        PortData;
        PortWait = 0;
        MaxPortWait = 0;
        MaxPortWaitAcq = 0;
        PortReadTime = 0;
        MaxPortReadTime = 0;
        port;
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
            javaaddpath('D:\0 Development');
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
            ReconTypeBytes = obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_MESSAGE_CONFIGURATION_FILE);
            obj.ReconType = strtok(char(ReconTypeBytes)',char(0));

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
            % Get DataHeader
            %--------------------------------------------
            Id = typecast(obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_MESSAGE_IDENTIFIER),'uint16');
            if Id ~= constants.MRD_MESSAGE_ISMRMRD_ACQUISITION
                error('fix ReadPortMetaData');
            end
            HeaderBytes = uint8(obj.SocketDataInputStream.readBuffer(constants.SIZEOF_MRD_ACQUISITION_HEADER));
            obj.DataHeader = ismrmrd.AcquisitionHeader(HeaderBytes);

            %--------------------------------------------
            % Initialize 'PortData'
            %--------------------------------------------            
            obj.IdentifierLength = constants.SIZEOF_MRD_MESSAGE_IDENTIFIER;
            obj.HeaderLength = constants.SIZEOF_MRD_ACQUISITION_HEADER;
            obj.TrajLength = double(obj.DataHeader.number_of_samples) * double(obj.DataHeader.trajectory_dimensions) * 4;
            obj.DataLength = double(obj.DataHeader.number_of_samples) * double(obj.DataHeader.active_channels) * 8;
            obj.TotalLength = obj.HeaderLength + obj.TrajLength + obj.DataLength + obj.IdentifierLength;
            obj.AcqsPerPortRead = floor(obj.PortDataSizeApprox / obj.TotalLength);
            obj.PortDataSize = obj.AcqsPerPortRead * obj.TotalLength;
            obj.PortData = zeros(obj.PortDataSize,1);   
        end
        
%==================================================================
% SetTotalPortReads
%==================================================================   
        function SetTotalPortReads(obj,NumAcqs,log)
            obj.TotalAcqs = NumAcqs;
            obj.ExpectedBytes = NumAcqs*obj.TotalLength - (obj.IdentifierLength+obj.HeaderLength);
            obj.TotalPortReads = ceil(NumAcqs/obj.AcqsPerPortRead);
        end
        
%==================================================================
% ReadPortData
%==================================================================    
        function ReadPortData(obj,log)
            obj.BufferReadNumber = obj.BufferReadNumber + 1;
            tic
            while true
                DataAtPort = obj.SocketInputStream.available;
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
