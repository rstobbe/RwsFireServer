%================================================================
%  
%================================================================

classdef RwsFireServer < RwsPortControl

    properties
        ReturnToCompass = 0;
        CompassSave = 0;
        SavePath = '';
    end

    methods
        
        function obj = RwsFireServer(port,log)
            obj@RwsPortControl(port,log);             
        end
        
%==================================================================
% Connect Client (in RwsPortControl)
%==================================================================         
        
%==================================================================
% Serve Client
%================================================================== 
        function ServeClient(obj,log) 
            while true
                try 
                    %--------------------------------------------
                    % Get MetaData
                    %--------------------------------------------
                    obj.ReadPortMetaData(log);

                    %--------------------------------------------
                    % Initialize Recon
                    %--------------------------------------------
                    func = str2func(obj.ReconHandlerName);
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
                    obj.TestScannerFinished(log);
                    log.info('Approximate Data Receive Rate: %d Mbps / Time Per Acq: %d us',round((obj.PortDataSize/max(obj.PortWait))*8/1e6),round(max(1000000*obj.PortWait)/obj.AcqsPerPortRead));

                    %--------------------------------------------
                    % Finish
                    %--------------------------------------------    
                    Recon.PostAcqProcess(obj,log);
                    Image = Recon.ReturnIsmrmImage(log);
                    log.info("Send Image to Scanner")
                    obj.SendOneImage(Image,log);
                    obj.SendClose(log);
                    if obj.ReturnToCompass
                        Recon.CompassReturnFire(obj,Recon,log);
                    end
                    if obj.CompassSave
                        Recon.CompassSaveFire(obj,Recon,log);  
                    end
                catch ME
                    log.error('[%s:%d] %s', ME.stack(1).name, ME.stack(1).line, ME.message);
                    obj.PortFinish;
                    rethrow(ME);
                end
            end
        end

%==================================================================
% ReturnHandler
%================================================================== 
        function Handler = ReturnHandler(obj)
            Handler = 'RwsFireServer';
        end             

%==================================================================
% SetCompassSave
%================================================================== 
        function SetCompassSave(obj,Path)
            obj.CompassSave = 1;
            obj.SavePath = Path;
        end           
 
%==================================================================
% SetCompassReturn
%================================================================== 
        function SetCompassReturn(obj)
            obj.ReturnToCompass = 1;
        end         
        
    end
end
