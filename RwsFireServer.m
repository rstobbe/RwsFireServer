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
                if strcmpi(obj.ReconType, 'StitchFire') || strcmpi(obj.ReconType, '''StitchFire''') 
                    log.info("Starting StitchFire")
                    Recon = StitchFire(obj,log);
                    obj.SetTotalPortReads(Recon.StitchMetaData.Nproj);
                end
                
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
                    Recon.ProcessData(obj,log);
                end
                log.info('Approximate Data Receive Rate: %d Mbps / Time Per Acq: %d us',round((obj.PortDataSizeApprox/max(obj.PortWait))*8/1e6),round(max(1000000*obj.PortWait)/obj.AcqsPerPortRead));
                
                %--------------------------------------------
                % Finish
                %--------------------------------------------    
                Recon.Finish(log);
                Image = Recon.ReturnImage(log);
                obj.SendOneImage(Image);
                obj.PortFinish;
                
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
