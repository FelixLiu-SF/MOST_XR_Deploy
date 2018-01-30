function [conn]=DeployMSAccessConn(mdbf_in)
% this is a function for creating a .mdb or .accdb connection object in a deployed Program

conn = [];

% check if mdbf_in exists
if(~exist(mdbf_in,'file'))
    return;
end

try
  connurl = ['jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' mdbf_in];
  conn = database('','','','sun.jdbc.odbc.JdbcOdbcDriver', connurl);
  ping(conn)

catch conn_err

  disp('Error connecting to database file');
  disp(conn_err.message);
end
