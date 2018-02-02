function [varargout]=DeployMDBquery(mdbf_in,sqlstr)
% [x_data]=DeployMDBquery(mdbname,sqlstr)
% [x_data,f_cols]=DeployMDBquery(mdbname,sqlstr)
%
% Robust MDBquery using DeployMSAccessConn.m

%  predefine outputs
x={};
f={};

% build connection object to MS Access file
[conn]=DeployMSAccessConn(mdbf_in);

try
    ping(conn);
    e = exec(conn,sqlstr);
    e = fetch(e);

    x = e.Data;
    f_col = columnnames(e);

    close(conn);

    %replace 'null' characters to empty cells
    for ix=1:size(x,1)
        for iy=1:size(x,2)
            if(strcmp(x{ix,iy},'null'))
                x{ix,iy} = [];
            end
        end
    end

catch
    try
        close(conn);
    catch
    end
end

varargout{1} = x;
if(nargout>1)
    if(~isempty(f_col))
        f_cell = textscan(strrep(f_col,'''','"'),'%q','Delimiter',',');
        f = f_cell{1};
        varargout{2} = f;
    else
        varargout{2} = {};
    end
end
