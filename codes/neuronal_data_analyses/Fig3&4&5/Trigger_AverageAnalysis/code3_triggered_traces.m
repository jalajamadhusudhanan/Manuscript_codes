function [allNeurons]=av_across_dat_2005_JM(wormAv)
     
    % "big function which  combine all labeled neuron trig averages"
    load triggered_alltraces.mat
    IdisGlob = LoadGlobalNeuronIDs';
    InterpSize = 450; %450 for stim trig, 300 for response(ava) trig %adjust according to your recording
    NumOfDatasets = length(wormAv);
    allNeurons =  struct('neuronName',IdisGlob, 'trigHit',[],'trigMiss', [], 'IndHit', [], 'IndMiss', [], 'trigAveargeHit', [], 'trigAveargeMiss', [], 'StdHit', [], 'StdMiss', [], 'SEMHit', [], 'SEMMiss',[]);
    

  %%  
    for iDataset = 1: NumOfDatasets
        
        %produces datasetORder - variable containing the list of the included in the analysis datasets names in the order in which also trials situated in the final variables trigHit and trigMiss 
%         datasetOrder = [datasetOrder; wormAv(iDataset).wormName];
        
        % produces variable "where_hit" containing a matrix with row
        % corresponding to "hit" trials, first column states the number of
        % datset from which trial came , the second column identifies time onset in frame
        % of this trial. "Where_hit" is stored in
        % "allNeurons(numOfThisId).IndHit". The same for "miss" trials. 
        indDataset_Hit = [];
        indDataset_Miss = [];
        
        indHit = []; ThisDataset_Hit = []; where_hit = [];
        indMiss = []; ThisDataset_Miss = []; where_miss = [];
        
        ThisDataset_Hit = iDataset.*ones(length( wormAv(iDataset).trig_vector.hit),1);
        ThisDataset_Miss = iDataset.*ones(length( wormAv(iDataset).trig_vector.miss),1);
        
        indDataset_Hit = [indDataset_Hit; ThisDataset_Hit];
        indDataset_Miss = [indDataset_Miss; ThisDataset_Miss];
        
        indHit = [indHit; wormAv(iDataset).trig_vector.hit'];
        indMiss= [indMiss; wormAv(iDataset).trig_vector.miss'];
        
        where_hit = [indDataset_Hit indHit];
        
        where_miss = [indDataset_Miss indMiss];
        tempStruct = wormAv(iDataset).trig_traces;
        
       % goes through all neurons in the tempStruct
            for iNeuron = 1 :size(tempStruct,1)
               
                 % check that this neuron is IDed
                if isempty(tempStruct(iNeuron).ID)
                    continue
%                 elseif ~ischar(tempStruct(iNeuron).ID{1})
%                     continue
                else

               
                numOfThisId = find(strcmp(IdisGlob, tempStruct(iNeuron).ID)==1);
               
                %%%interpolation
                x_int = linspace(0,1, InterpSize);
                if ~ isempty(tempStruct(iNeuron).trigAvHit)
                x_orig = linspace(0, 1, size(tempStruct(iNeuron).trigAvHit, 2));
                ThisIdInterp.trigHit = (interp1(x_orig,tempStruct(iNeuron).trigAvHit', x_int))'; 
                if size(ThisIdInterp.trigHit,1)==InterpSize
                     ThisIdInterp.trigHit=ThisIdInterp.trigHit';
                end  
                    %collects interpolated trigHit trials
                    allNeurons(numOfThisId).trigHit = [allNeurons(numOfThisId).trigHit; ThisIdInterp.trigHit];
                    %
                    allNeurons(numOfThisId).IndHit = [allNeurons(numOfThisId).IndHit; where_hit];
                end
                
                %the same for "miss" trials
                    if ~ isempty(tempStruct(iNeuron).trigAvMiss)
                    x_orig = linspace(0, 1, size(tempStruct(iNeuron).trigAvMiss, 2));
                    ThisIdInterp.trigMiss = (interp1(x_orig,tempStruct(iNeuron).trigAvMiss', x_int))'; 
                     if size(ThisIdInterp.trigMiss,1)==InterpSize
                     ThisIdInterp.trigMiss=ThisIdInterp.trigMiss';
                end  
                    allNeurons(numOfThisId).trigMiss=[allNeurons(numOfThisId).trigMiss; ThisIdInterp.trigMiss];
                    allNeurons(numOfThisId).IndMiss = [allNeurons(numOfThisId).IndMiss; where_miss];         
                end     
            end 
        end
    end 
 %%  eleminate empty elements corresponding to neruons IDs not found in any dataset
    iElement = 1;   
    while iElement <= size(allNeurons,2)
        
        if (isempty (allNeurons(iElement).trigHit)) | (isempty (allNeurons(iElement).trigMiss))
             allNeurons(iElement) = [];
        else
            
            %now calculate the mean between all hit trials and std,sem
            allNeurons(iElement).trigAveargeHit =   mean(allNeurons(iElement).trigHit,1);
            allNeurons(iElement).StdHit =   std(allNeurons(iElement).trigHit,1);
            allNeurons(iElement).SEMHit =   std(allNeurons(iElement).trigHit)/sqrt(size(allNeurons(iElement).trigHit,1));
            
            %the same for miss trials
            allNeurons(iElement).trigAveargeMiss =   mean(allNeurons(iElement).trigMiss,1);
            allNeurons(iElement).StdMiss =   std(allNeurons(iElement).trigMiss,1);
            allNeurons(iElement).SEMMiss =   std(allNeurons(iElement).trigMiss)/sqrt(size(allNeurons(iElement).trigMiss,1));
            iElement=iElement+1;
        end
    
    end
    
save allNeurons_Avg_restrig_hit&miss allNeurons
end 

