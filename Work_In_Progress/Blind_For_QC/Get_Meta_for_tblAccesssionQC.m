function [matsave, final]=Get_Meta_for_tblAccesssionQC(dcmdir_in)
% [matsave, final]=Get_Meta_for_tblAccesssionQC(dcmdir_in);

warning('off','images:dicominfo:unhandledCharacterSet');

datenow = datestr(now,'yyyymmddHHMMSS');
matsave = horzcat('Records_tblAccessionQC_',datenow,'.mat');

[~,~,dcmlist]=foldertroll(dcmdir_in,'');

final = {};
for ix=1:size(dcmlist,1)
    
    tmpf = dcmlist{ix,1};
    info = dicominfo(tmpf);
    
    rid     = info.PatientID;
    sedesc  = info.SeriesDescription;
    acc     = info.AccessionNumber;
    SOP     = info.SOPInstanceUID;
    sdate   = info.StudyDate;
    
    
    se1 = regexpi(sedesc,'(PA05|PA10|PA15|RLAT|LLAT|Full Limb)','match');
    if(~isempty(se1))
        se2 = se1{1};
    else
        se2 = '';
    end
    
    if(~isempty(se2))
        barc1 = regexp(sedesc,'6[0-9]*','match');
        barc2 = barc1{1};

        switch se2
            case 'PA05'
                se3 = 3;
            case 'PA10'
                se3 = 1;
            case 'PA15'
                se3 = 2;
            case 'RLAT'
                se3 = 5;
            case 'LLAT'
                se3 = 4;
            case 'Full Limb'
                se3 = 6;
            otherwise
                se3 = 0;

        end

        tmpdate = sdate;
        if(isempty(tmpdate))
            tmpdate = info.ContentDate;
        end

        if(strcmpi(tmpdate(1:4),'2016') || strcmpi(tmpdate(1:4),'2017') || strcmpi(tmpdate(1:4),'2018') || strcmpi(tmpdate(1:4),'2019') || strcmpi(tmpdate(1:4),'2020'));

            final{end+1,1}  = tmpf;
            final{end,2}    = '';
            final{end,3}    = rid;
            final{end,4}    = barc2;
            final{end,5}    = se3; 
            final{end,6}    = se2;
            final{end,7}    = sdate;
            final{end,8}    = acc;
            final{end,9}    = SOP;

        end
    end
end

save(matsave,'final');
