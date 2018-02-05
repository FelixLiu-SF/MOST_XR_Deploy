function UpdateMDB(mdbf_in,tbl_name,tbl_fields,tbl_to_upload,where_clause)
% this function updates a table in a MS Access database according to the where clause

[conn] = DeployMSAccessConn(mdbf_in);

if(~isempty(conn))

  try

    for ix=1:size(tbl_to_upload)
      update(conn,tbl_name,tbl_fields,tbl_to_upload(ix,:),{where_clause{ix,1}});
      pause(0.05);
    end

    close(conn);

  catch update_err

    disp(update_err.message)
    close(conn);

  end

end
