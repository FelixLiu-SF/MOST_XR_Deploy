function []=Upload_Accession_MOST(final,force_update)
% Upload_Accession_MOST(final,force_update);
% 
% force_update=1 will always update existing fields
% force_update=0 will only update accession and SOPInstanceUID
% force_update=-1 will skip all repeat barcodes or SOPInstanceUID


if(size(final,1)<1)
    disp('Invalid input.');
    return;
end

final(:,5) = cellfun(@num2str,final(:,5),'UniformOutput',0);

master_mdbf = '\\fu-hsingb\most\Imaging\144-month\MOST_XR_144M_Master.accdb';
[x,f] = MDBquery(master_mdbf,'SELECT * FROM tblAccessionQC');

pause(5);
connurl = ['jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' master_mdbf];
conn = database('','','','sun.jdbc.odbc.JdbcOdbcDriver', connurl);

disp(size(final,1));
for ix=1:size(final,1)
    
    tmpbarc1 = final{ix,4};
    tmpsop = final{ix,9};
    tmpsopreg = strrep(tmpsop,'.','\.');
    
    jx = indcfind(x(:,indcfind(f,'^BARCODE$','regexpi')),tmpbarc1,'regexpi');
    kx = indcfind(x(:,indcfind(f,'^SOPINSTANCEUID$','regexpi')),tmpsopreg,'regexpi');
    
    if(isempty(kx))
        %insert new record
        try
            ping(conn);
            fastinsert(conn,'tblAccessionQC',f(2:end)',final(ix,3:end)); pause(0.2);
        catch inserterr
            disp(inserterr.message);
        end
    else
        disp(x(kx,:));
        %check and update new record
%         whereclause = horzcat('WHERE BARCODE=''',tmpbarc1,'''');
        whereclause = horzcat('WHERE (SOPINSTANCEUID=''',tmpsop,''' AND BARCODE IS NULL)');
        try
            ping(conn);
            if(force_update==1)
                update(conn,'tblAccessionQC',f(2:end),final(ix,3:end),whereclause);
                disp(final(ix,:));
            elseif(force_update==0)
                chk_acc = x{jx(1),7};
                chk_sop = x{jx(1),7};
                if(isempty(chk_acc) || isempty(chk_sop))
                    update(conn,'tblAccessionQC',f(7:8),final(ix,8:9),whereclause);
                end
                disp(final(ix,:));
            elseif(force_update==-1)
                %skip this record
                disp('skip');
            end
        catch updateerr
            disp(updateerr.message);
        end
    end

end

close(conn);