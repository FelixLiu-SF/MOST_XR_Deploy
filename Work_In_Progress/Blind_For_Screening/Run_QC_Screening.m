
try
    disp('Process MOST Screening XRs');
    addpath('C:\Matlab_Code\Universal\');
    addpath('E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Common_code');
    
    datedir = datestr(now,'yyyymmdd');
    savename = horzcat('Screening_',datedir,'.mat');
    
    resendname =    horzcat('Resend_',datedir,'.mat');
    incidfindname = horzcat('IncidentalFindings_',datedir,'.mat');
    
    disp(datedir);
    
    if(~exist(savename,'file'))
    
        [dcmdir_in,final_ID_unblinded]=Get_New_Screening_XRs;                           save(savename,'savename','final_ID_unblinded','dcmdir_in','datedir');

        

        if(size(final_ID_unblinded,1)>0)
            
            disp(horzcat(num2str(size(unique(final_ID_unblinded(:,3)),1)),' Screening XR IDs.'));
            
            [dcm_inven]=Get_ScreeningXR_MetaView(dcmdir_in);                                save(savename,'savename','dcm_inven','-append');
            [nn_se]=Get_NeuralNet_Screening(dcm_inven);                                               save(savename,'savename','nn_se','-append');

            dcm_inven(:,10) = nn_se(:,3);
            [dcm_inven]=Rejigger_ScreeningSE(dcm_inven,nn_se);
            dcm_inven = sortrows(dcm_inven,[3,10]);

            [prefill_out,acc_out,dcmdir_out,tagmod]=Blind_Recd_ScreeningXR(dcmdir_in,dcm_inven);   save(savename,'prefill_out','acc_out','dcmdir_out','tagmod','-append');

            [BA_out]=Proc_MOST_Screening_BA_Dir(dcmdir_out);                        save(savename,'BA_out','-append');
            [acc_out,prefill_out]=Relabel_PA_views(BA_out,acc_out,prefill_out);     save(savename,'prefill_out','acc_out','-append');
            
            
            %check for IDs to resend
            if(exist(resendname,'file'))
                try
                    load(resendname,'idlist');
                    for jx=1:size(idlist,1)
                        tmpid =         idlist{jx,1};
                        tmpdatedir =    idlist{jx,2};

                        oldsave = load(horzcat('Screening_',tmpdatedir,'.mat'));

                        acc_out = [oldsave.acc_out(indcfind(oldsave.acc_out(:,1),tmpid,'regexpi'),:); acc_out];
                        prefill_out = [oldsave.prefill_out(indcfind(oldsave.prefill_out(:,1),tmpid,'regexpi'),:); prefill_out];

                        [tmplistdir,~] = listdir(oldsave.dcmdir_out,0);
                        olddcm = tmplistdir{indcfind(tmplistdir(:,1),tmpid,'regexpi'),1};
                        [oldd,oldf,olde] = fileparts(olddcm);
                        copyfile(olddcm,horzcat(dcmdir_out,oldf));

                    end
                catch resend_err
                    disp(resend_err.message);
                end
            end
            %
            
            %check for Full Limb & Misc. XR incidental findings for review
            if(exist(incidfindname,'file'))
                try
                    incidfindload = load(incidfindname);
                    for jx=1:size(incidfindload.idlist,1)
                        
                        tmpid =         incidfindload.idlist{jx,1};
                        tmpdatedir =    incidfindload.idlist{jx,2};
                        
                        acc_out = [incidfindload.acc_out(indcfind(incidfindload.acc_out(:,1),tmpid,'regexpi'),:); acc_out];
                        prefill_out = [incidfindload.prefill_out(indcfind(incidfindload.prefill_out(:,1),tmpid,'regexpi'),:); prefill_out];

                        [~,tmplistifdir] = listdir('E:\MOST-Renewal-II\XR\BLINDING\For_IncidentalFindings\TEMP_BLINDED',1);
                        tmplistdir = tmplistifdir{2};
                        olddcm = tmplistdir{indcfind(tmplistdir(:,1),tmpid,'regexpi'),1};
                        [oldd,oldf,olde] = fileparts(olddcm);
                        copyfile(olddcm,horzcat(dcmdir_out,oldf));
                        
                    end
                catch incidfind_err
                    disp(incidfind_err.message);
                end
            end
            
            
            %% create MDB Scoresheet
            [mdbf]=Deploy_Screening_Scoresheet(prefill_out, acc_out, dcmdir_out);           save(savename,'mdbf','-append');
            
            %check for Adjudications
            [x_adj,f_adj]=Get_Adj_from_DF(datedir,30);
            if(size(x_adj,1)>0)
                [x_adj, prefill_add]=Copy_Adj_from_DF(dcmdir_out,mdbf,x_adj,f_adj);
                if(size(prefill_add,1)>0)
                    prefill_out = [prefill_out; prefill_add];
                end
                
                save(savename,'x_adj','f_adj','prefill_add','-append');
            end
            
            %% Update MDB for IF comments
            if(exist(incidfindname,'file'))
                Update_MDB_for_IF_Comments(incidfindload.idlist,mdbf);
            end
            
            delbak(dcmdir_out);
            
            try
                destdir = horzcat('C:\Users\fliu2\Box Sync\OAI_XR_ReaderA\MOST\DICOM\',datedir);
                [s1,m1] = robofun(dcmdir_out,destdir,'',0);
                pause(1);
                [s2,m2] = robofun(dcmdir_out,destdir,'',0);
                
                [~,mdbfn,mdbfe] = fileparts(mdbf);
                destf = horzcat('C:\Users\fliu2\Box Sync\OAI_XR_ReaderA\MOST\Scoresheets\',mdbfn,mdbfe);
                copyfile(mdbf,destf);
                
                pause(60*10);
                
            catch roboerr
                pause(60*10);
                disp(roboerr.message);
            end
            
            % generate automated email
            u_id = unique(prefill_out(:,1));
            if(size(u_id,1)>0)
                u_sz = num2str(size(u_id,1));
                
                [~,mdbfn,~]=fileparts(mdbf);
                
                em_to = 'paliabadi@bwh.harvard.edu';
                em_cc = 'fliu@psg.ucsf.edu';
                em_body_1 = 'Dear Dr. Aliabadi, <br><br><br>The following X-rays and scoresheets for MOST Knee Screening have been uploaded to you on Box Sync: <br><br>';
                em_body_2 = horzcat(mdbfn,' - ',u_sz,' participant(s)');
                em_body_3 = '<br><br>Please review them at your leisure.<br>Thank you<br><br>';
                em_body_4 = 'This is an automated message.';
                
                em_subject = horzcat('MOST Knee Screening ',datestr(now,'yyyy-mm-dd'));
                
                
                em_body_final = horzcat(em_body_1,...
                    '<b>',em_body_2,'</b>',...
                    em_body_3,...
                    '<p style="font-size:84%">',em_body_4,'</p>');
                
                try
                    sendolmail(em_to,em_subject,em_body_final,'',em_cc,'');
                catch
                    pause(60*30);
                    sendolmail(em_to,em_subject,em_body_final,'',em_cc,'');
                end
                
            end
            
        else
            
            em_to = 'fliu@psg.ucsf.edu';
            em_cc = 'felix.liu@ucsf.edu';
            em_subject = horzcat('MOST XR no new screening ppts ',datestr(now,'yyyy-mm-dd'));
            em_body_final = datestr(now);

            sendolmail(em_to,em_subject,em_body_final,'',em_cc,'');

        end
    
        delbak('C:\Users\fliu2\Box Sync\OAI_XR_ReaderA\MOST\DICOM');
        
    else
        
        disp('Process already ran today.');
        
    end
    
catch runerr
    disp('Error encountered.');
    disp(runerr.message)
    save(savename,'runerr','-append');
    

    em_to = 'fliu@psg.ucsf.edu';
    em_cc = 'felix.liu@ucsf.edu';
    em_subject = horzcat('MOST XR ERROR ',datestr(now,'yyyy-mm-dd'));
    em_body_final = datestr(now);
    
    sendolmail(em_to,em_subject,em_body_final,'',em_cc,'');
    
    exit;
end
disp('Process finished.');
exit;