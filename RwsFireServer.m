%================================================================
%  
%================================================================

classdef RwsFireServer < RwsPortControl

    properties
    end

    methods
        
        function obj = RwsFireServer(port,log)
            obj@RwsPortControl(port,log);             
        end
        
%==================================================================
% Connect Client (in RwsPortControl)
%==================================================================         
        %function ConnectClient(obj)
        
%==================================================================
% Serve Client
%================================================================== 
        function ServeClient(obj,log) 
            try 
                %--------------------------------------------
                % Get MetaData
                %--------------------------------------------
                obj.ReadPortMetaData(log);
                
                %--------------------------------------------
                % Initialize Recon
                %--------------------------------------------
                func = str2func(obj.ReconType);
                Recon = func(obj,log);
                
                %--------------------------------------------
                % Read Port Data and Process
                %--------------------------------------------                
                log.info("Wait for Data")
                for n = 1:obj.TotalPortReads
                    obj.ReadPortData(log);
                    if (n*obj.AcqsPerPortRead) < obj.TotalAcqs
                        log.info('ReceiveData: %d:%d Acqs / PortWait: %d ms',n*obj.AcqsPerPortRead,obj.TotalAcqs,round(1000*obj.PortWait(n)));
                    else
                        log.info('ReceiveData: %d:%d Acqs / PortWait: %d ms',obj.TotalAcqs,obj.TotalAcqs,round(1000*obj.PortWait(n)));
                    end
                    Recon.IntraAcqProcess(obj,log);
                end
                log.info('Approximate Data Receive Rate: %d Mbps / Time Per Acq: %d us',round((obj.PortDataSize/max(obj.PortWait))*8/1e6),round(max(1000000*obj.PortWait)/obj.AcqsPerPortRead));
                
                %--------------------------------------------
                % Finish
                %--------------------------------------------    
                Recon.PostAcqProcess(obj,log);
                Image = Recon.ReturnIsmrmImage(log);
                obj.SendOneImage(Image);
                obj.PortFinish;
                Recon.CompassReturnFire(obj,Recon,log);
                
            catch ME
                log.error('[%s:%d] %s', ME.stack(1).name, ME.stack(1).line, ME.message);
                obj.PortFinish;
                rethrow(ME);
            end
        end

%==================================================================
% Delete
%==================================================================         
        function delete(obj)
        end
        
    end
    
end
