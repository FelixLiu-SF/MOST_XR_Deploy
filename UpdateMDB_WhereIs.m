function UpdateMDB_WhereIs(mdbf_in,tbl_name,tbl_fields,tbl_to_upload,where_field,where_is,is_str)
% this function updates a table, creating where clauses for each row with where_field=where_is as the where clause
% set is_str flag to 1 if where_is is type string, otherwise set to 0

tmpwhere = {};

where_part_1 = cell(size(tbl_to_upload,1));
where_part_1(:) = {'WHERE '};

where_part_2 = cell(size(tbl_to_upload,1));
where_part_2(:) = {where_field};

if(is_str==1)
  where_part_3 = cell(size(tbl_to_upload,1));
  where_part_3(:) = {'='''};
  where_part_4 = cell(size(tbl_to_upload,1));
  where_part_4(:) = {''''};
else
  where_part_3 = cell(size(tbl_to_upload,1));
  where_part_3(:) = {'='};
  where_part_4 = cell(size(tbl_to_upload,1));
  where_part_4(:) = {''};
end

tmpwhere = cellfun(@horzcat,where_part_1,where_part_2,where_part_3,where_is,where_part_4,'UniformOutput',0);

UpdateMDB(mdbf_in,tbl_name,tbl_fields,tbl_to_upload,where_field,tmpwhere);
