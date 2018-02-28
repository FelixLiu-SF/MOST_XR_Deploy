function [tmpseries_out]=Relabel_XR_PA_Views_Deploy(tmpseries)
%% relabel the PA XR views for blinding

% calculate a beam angle for each PA view
for fx=1:size(tmpseries,1)

  tmpf = tmpseries{fx,1};
  try
    [~,aR,aL,aC,~,~,~,~,~,~,~,~,~,~,~,~,~,~,~,~]=CalcBeamAngle2016(tmpf);
    if(~isempty(aC))
      thisCalcBA = aC;
    else
      thisCalcBA = mean([aR;aL]);
    end

    tmpseries{fx,7} = thisCalcBA;
    
    BAchoice = [5,10,15];
    [~,bx] = min(abs(BAchoice - abs(thisCalcBA)));
    trueBA = BAchoice(1,bx);

    if(abs(thisCalcBA)<=7.75)
      trueBA = 5;
    end

    tmpseries{fx,8} = trueBA;
    
    disp(thisCalcBA); disp(trueBA);


  catch beamangle_err
      
    disp(beamangle_err.message);  
      
    thisCalcBA = 0;
    trueBA = 10;

    tmpseries{fx,7} = thisCalcBA;
    tmpseries{fx,8} = trueBA;
  end

end %fx

% compare the beam angles for the PA exam as a whole
tmpseries = sortrows(tmpseries,[7,8,6,2,1]);
if(size(tmpseries,1)>1)

  if(size(unique(cell2mat(tmpseries(:,8))),1) < size(tmpseries,1))
    [likely_PA10,jx10] = min(abs(10 - abs(cell2mat(tmpseries(:,7))) ));
    if(likely_PA10<=3.0)
      for fx=1:size(tmpseries,1)
        thisCalcBA = tmpseries{fx,7};

        if(thisCalcBA<=(likely_PA10-2.5)) %2.5 degrees lower, likely PA05
          tmpseries{fx,8} = 5;
        elseif(thisCalcBA>=(likely_PA10+2.5)) % 2.5 degrees higher, likely PA15
          tmpseries{fx,8} = 15;
        else % likely another PA10
          tmpseries{fx,8} = 10;
        end

      end
    end

  end % compare number of views to number of files

else
  % double check if beam angle is close to 10
  thisCalcBA = tmpseries{1,7};
  if(thisCalcBA>7.25 && thisCalcBA<12.5)
    tmpseries{1,8} = 10;
  end
end

% relabel the PA series description
for fx=1:size(tmpseries,1)
  trueBA = tmpseries{fx,8};
  tmpseries{fx,6} = horzcat('PA',zerofillstr(trueBA,2));
end

% output the results
tmpseries_out = tmpseries(:,1:6);
