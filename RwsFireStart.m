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
    
    log.info('Initialize server on port %d', port);
    Server = RwsFireServer(port,log);
    
    log.info('Wait for client');
    Server.ConnectClient(log);

    log.info('Serve client');
    Server.ServeClient(log);    
    
end
