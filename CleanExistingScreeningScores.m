function [x_out, f_out] = CleanExistingScreeningScores(x_in, f_in)
% [x_out, f_out] = CleanExistingScreeningScores(x_in, f_in);

%% initialize
x_out = x_in;
f_out = f_in;

%% remove extra COMMENTS_SFCC column
col_COMMENTS_SFCC = indcfind(f_out,'^COMMENTS_SFCC$','regexpi');
if(~isempty(col_COMMENTS_SFCC))
    x_out(:,col_COMMENTS_SFCC) = [];
    f_out(col_COMMENTS_SFCC,:) = [];
end

%% Clean up comments and signatures
col_READER =            indcfind(f_out,'^READER$','regexpi');
col_EDATE =             indcfind(f_out,'^E_DATE$','regexpi');
col_ETIME =             indcfind(f_out,'^E_TIME$','regexpi');
col_COMMENTS =          indcfind(f_out,'^COMMENTS$','regexpi');
col_COMMENTS_REVIEW =   indcfind(f_out,'^COMMENTS_REVIEW$','regexpi');

for ix=1:size(x_out,1)
    
    if(isempty(x_out{ix,col_COMMENTS}))
        x_out{ix,col_COMMENTS} = '';
    end
    
    if(isempty(x_out{ix,col_COMMENTS_REVIEW}))
        x_out{ix,col_COMMENTS_REVIEW} = '';
    end
    
    tmp_comments = horzcat(x_out{ix,col_COMMENTS},' ',x_out{ix,col_COMMENTS_REVIEW});
    tmp_comments = strtrim(tmp_comments);
    
    if(length(tmp_comments)>255)
        tmp_comments = horzcat(tmp_comments(1:254),'-');
    end
    
    x_out{ix,col_READER} = '';
    x_out{ix,col_EDATE}  = '';
    x_out{ix,col_ETIME}  = '';
    x_out{ix,col_COMMENTS}  = 'Dr Felson has requested adjudication for this exam. Please review and confirm KLG scores';
    x_out{ix,col_COMMENTS_REVIEW}  = tmp_comments;
    
end