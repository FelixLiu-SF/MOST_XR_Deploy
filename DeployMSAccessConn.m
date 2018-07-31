function [conn]=DeployMSAccessConn(mdbf_in)
% this is a function for creating a .mdb or .accdb connection object in a deployed Program

conn = [];

% check if mdbf_in exists
if(~exist(mdbf_in,'file'))
    return;
end

% check if called from deployed application

if(isdeployed)

    try
      connurl = ['jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' mdbf_in];
      conn = database('','','','sun.jdbc.odbc.JdbcOdbcDriver', connurl);

    catch conn_err

      disp('Error connecting to database file');
      disp(conn_err.message);
    end

else % desktop application, try ucanaccess driver
    
    warning('off','database:driver:FunctionToBeRemoved');
    warning('off','MATLAB:Java:DuplicateClass');
    
    % load the UCanAccess jar files from http://ucanaccess.sourceforge.net/site.html
    try 
        javaaddpath('C:\Users\fliu2\Documents\MATLAB\MSAccess\UCanAccess-3.0.6-bin\UCanAccess-3.0.6-bin\lib\jackcess-2.1.3.jar');
        javaaddpath('C:\Users\fliu2\Documents\MATLAB\MSAccess\UCanAccess-3.0.6-bin\UCanAccess-3.0.6-bin\lib\hsqldb.jar');
        javaaddpath('C:\Users\fliu2\Documents\MATLAB\MSAccess\UCanAccess-3.0.6-bin\UCanAccess-3.0.6-bin\lib\commons-logging-1.1.1.jar');
        javaaddpath('C:\Users\fliu2\Documents\MATLAB\MSAccess\UCanAccess-3.0.6-bin\UCanAccess-3.0.6-bin\lib\commons-lang-2.6.jar');
        javaaddpath('C:\Users\fliu2\Documents\MATLAB\MSAccess\UCanAccess-3.0.6-bin\UCanAccess-3.0.6-bin\ucanaccess-3.0.6.jar');
    catch addjava_err
    end
    
    % construct each connection url
    ucan_url = horzcat('jdbc:ucanaccess://',mdbf_in);
    odbc_url = horzcat('jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=',mdbf_in);

    d_ucan = driver(ucan_url);
    d_odbc = driver(odbc_url);

    try
        conn1 = database('','','','net.ucanaccess.jdbc.UcanaccessDriver', ucan_url);
        ping(conn1);
        conn = conn1;
        
    catch ucan_err
        conn2 = database('','','','sun.jdbc.odbc.JdbcOdbcDriver', odbc_url);
        try
            ping(conn2);
            conn = conn2;
            
        catch odbc_err
            
            try
              connurl = ['jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' mdbf_in];
              conn = database('','','','sun.jdbc.odbc.JdbcOdbcDriver', connurl);

            catch conn_err_final

              disp('Error connecting to database file');
              disp(conn_err.message);
              
            end
            
            
        end
    end
    
    
end