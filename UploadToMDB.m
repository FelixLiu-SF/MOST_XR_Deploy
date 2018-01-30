function UploadToMDB(mdbf_in,tbl_name,tbl_fields,tbl_to_upload)
% this function uploads a table to a MS Access database

[conn] = DeployMSAccessConn(mdbf_in);

if(~isempty(conn))

  try

    for ix=1:size(tbl_to_upload)
      fastinsert(conn,tbl_name,tbl_fields,tbl_to_upload(ix,:));
      pause(0.05);
    end

    close(conn);
  catch
    close(conn);
  end
  
end
