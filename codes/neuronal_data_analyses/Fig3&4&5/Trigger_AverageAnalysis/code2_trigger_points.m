function [wormAv] = stimtrigstim_2005_JM(min_win, max_win,typeF)
% This function chuncks traces of all neurons around trig points defined by
% triggering vector - separately for HIT and MISS trials; wormAv is an
% output structure. Works together with stimtrig_over_dat_2005 to go
% through datasets. 
% track can be original traces from wbstrcut or traces_corrected made with Manuels additional bleach correction 

% headtail = [dir('*head*'), dir('*tail*')];

%first loads trig vector
% cd ( headtail(1).name )
stimdelay= 0; %sec 
trials=16;
load('hit_miss_trials.mat')
response=NaN(length(output)+1,trials+1);
for i=1:length(output);
if strcmpi(typeF,'stim')
   Trig1 = output(i).trigger_vector.trials_hit;
   Trig2 = output(i).trigger_vector.trials_miss;
   disp('stim type')
    elseif strcmpi(typeF,'ava')
        Trig1 = output(i).trigger_vector.ava_hit_low;
        Trig2 = output(i).trigger_vector.ava_rest;
        stimdelay=0;
        disp('ava type')
    elseif strcmpi(typeF,'urx')
        Trig1 = output(i).trigger_vector.urx_hit;
        Trig2 = output(i).trigger_vector.urx_miss;
        disp('urx type')
    elseif strcmpi(typeF,'IL2L')
        Trig1 = trig_vector.IL2L_hit;
        Trig2 = trig_vector.IL2L_miss;
        disp('IL2L type')
    elseif strcmpi(typeF,'AQR')
        Trig1 = trig_vector.AQR_hit;
        Trig2 = trig_vector.AQR_miss;
        disp('AQR type')
    elseif strcmpi(typeF,'EarlSens')
        Trig1 = trig_vector.EarliestSens_hit;
        Trig2 = trig_vector.EarliestSens_miss;
        disp('EarlSens type')
    elseif strcmpi(typeF,'AVA_low')
        Trig1 = output(i).trigger_vector.trials_hit_AVAlow;
        Trig2 = output(i).trigger_vector.trials_miss_AVAlow;
        disp('AVA_low')    
    elseif strcmpi(typeF,'hit after hit')   
        Trig1 = trig_vector.trials_hit_afterHit;
        Trig2 = trig_vector.trials_hit_afterMiss;
        disp('hit afer hit')
    elseif strcmpi(typeF,'miss after hit')
        Trig1 = trig_vector.trials_miss_afterHit;
        Trig2 = trig_vector.trials_miss_afterMiss;
        disp('miss afer hit')
    elseif strcmpi(typeF,'hitMiss after hit')   
        Trig1 = trig_vector.trials_hit_afterHit;
        Trig2 = trig_vector.trials_miss_afterHit;
        disp('hitMiss afer hit')
    elseif strcmpi(typeF,'hitMiss after miss')   
        Trig1 = trig_vector.trials_hit_afterMiss;
        Trig2 = trig_vector.trials_miss_afterMiss;
        disp('hitMiss afer hit')
    end
%    wormName = split(pwd,'\');
%    wormName = wormName{end};
%    wormname = ['wormAv_' wormName];
   wormAv(i).wormName = output(i).wormID;
  
% goes through head and tail folders   
for headTail = 1:2
switch headTail 
    case 1
       load WBstruct_head_data_extracted.mat
    case 2
        load WBstruct_tail_data_extracted.mat
end
% wbstruct = load('Quant/wbstruct.mat');
IdisLoc = Results(i).NeuronNames;
IdisLoc = convert_cells_to_chararray(IdisLoc);
FrRate = Results(i).fps;

datasetSummary = struct('ID', cell(length(IdisLoc),1), 'trigAvHit', [], 'trigAvMiss', []);
   

  % goes through all neurons
 for neuronI=1: length(Results(i).NeuronNames)
     
     % allocate names of neurons if it existis, otherwise empty
      if isempty( IdisLoc{neuronI})
       datasetSummary(neuronI).ID = [];
      else
       datasetSummary(neuronI).ID = IdisLoc{neuronI};
      end 
%     track = Results(i).Bleachcorrected_traces(:,neuronI);
    track = Results(i).deltaFOverF(:,neuronI); 
    annotation_temp=[];
    stimulus=[];
    annotation_temp= 2 * ones(length(track), 1);
    stimulus=11 * ones(length(track), 1);
    % use already corrected traces
%     track = Results(i).Bleachcorrected_traces(:,neuronI);
     % smooth the trace
      track = smoothdata(track,'movmean',4);
% %       track=diff(track);
%      %track = Results(i).deriv_traces(:,neuronI); 
%     % normalisation by z-scoring
      track = (track-mean(track))/std(track);
    
    chunks_hit = [];
    
     for l = 1:length(Trig1) %1:num_stim_up-1
         selStim = Trig1(l)+ stimdelay*FrRate ;
         winStart = selStim + min_win*FrRate;
         winEnd = selStim + max_win*FrRate;
         trigWindow = round (winStart:winEnd);
         chunks_hit(l,:) = track(trigWindow);
         annotation_temp(trigWindow)=1;
         stimulus(trigWindow)=21;
     end
     
       datasetSummary(neuronI).trigAvHit = chunks_hit;
    
%     peth_hit(j,:)= nanmean(chuncks_hit,1);
%     StDev_hit(j,:) = nanstd (chuncks_hit); 
%     SEM_hit(j,:)=  std (chuncks_hit)/sqrt(length(Trig1));
    
 chunks_miss = [];

     for k = 1:length(Trig2) %1:num_stim_up-1
         selStim = Trig2(k)+stimdelay*FrRate ;
         winStart = selStim + min_win*FrRate;
         winEnd = selStim + max_win*FrRate;
         trigWindow = round(winStart:winEnd);
         chunks_miss(k,:) = track(trigWindow);
         annotation_temp(trigWindow)=0;
         stimulus(trigWindow)=21;
     end
     
    datasetSummary(neuronI).trigAvMiss = chunks_miss;

%   peth_miss(j,:)= nanmean(chuncks_miss,1);
%     StDev_miss(j,:) = nanstd (chuncks_miss); 
%     SEM_miss(j,:)= nanstd (chuncks_miss)/sqrt(length(Trig2));
    
end
%
  switch headTail
      case 1
          a= datasetSummary;
      case 2 
          b= datasetSummary;          
  end 

end

wormAv(i).trig_traces=cat(1,a,b);

%add trig_vector itself in the output stucture
wormAv(i).trig_vector.hit =  Trig1;
wormAv(i).trig_vector.miss =  Trig2;
wormAv(i).annotation=annotation_temp;
wormAv(i).stimulus=stimulus;
response(i,output(i).ind_vec.avaLowHit)=1;
response(i,output(i).ind_vec.avaLowMiss)=0;
 %save(['D:\RECORDINGS\STIMULUS\var_corrected_AVA_trig_norm\',wormname], 'wormAv')
end
save triggered_alltraces  wormAv
end