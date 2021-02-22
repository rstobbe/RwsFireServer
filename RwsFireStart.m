%================================================================
%  
%================================================================

function RwsFireStart(varargin)

    if nargin < 1
        port = 9002; 
    else
        port = varargin{1};
    end
    
    if nargin < 2
        logfile = '';
    else
        logfile = varargin{2};
    end

    log = logging.createLog(logfile);
    
    log.info('Initialize Server on Port %d', port);
    Server = RwsFireServer(port,log);
    
    Server.SetCompassSave('E:\_TempFireImages\');
    Server.ServeClient(log);       
end
