% IdisGlob = LoadGlobalNeuronIDs';
IdisGlob={'IL2L';'IL2R';'AQR';'URXL';'URXR';'PQR';'RMGL';'RMGR';'AUAL';'AUAR';'PVPL';'PVPR';'BAGL';'BAGR';'ASEL';'ASER';'AIBL';'AIBR';'AVAL';'AVAR';'RIML';'RIMR';'AVEL';'AVER';'AS10';'DA01';'VA01';'DA07';'DA09';'VA12';'VD13';'VA11';'DVC';'URADL';'URADR';'URYDL';'URYDR';'URYVL';'URYVR';'OLQDL';'OLQDR';'OLQVL';'RIBL';'RIBR';'ALNL';'ALNR';'AVBL';'PVNL';'PVNR';'DB01';'DB02';'DB07';;'VB01';'VB02';'VB11';'DVA';'SMBDL';'SMBDR';'SMDDL';'SMDDR';'SIADL';'SIADR';'SMDVL';'SMDVR';'RIVL';'RIVR';'SMBVL';'SMBVR';'RID';'RIS';'ALA';'ASKL';'ASKR';'AIZL';'AIZR';'DVB';'PHBL';'PHBR';'VD11';'PDA'}
InterpSize=9450;
alltraces =  struct('neuronName',IdisGlob, 'trace', [], 'Average_trace', []);
for headtail = 1:2
         switch headtail
               case 1
        load('WBstruct_head_data_extracted.mat', 'Results')     
             case 2
        load('WBstruct_tail_data_extracted.mat', 'Results')       
         end
% for i= 1: length(Results)
i=4
    tempStruct = []; Neurons=[];
    Neurons = convert_cells_to_char(Results(i).NeuronNames);
     tempStruct = Results(i).deltaFOverF';
%      tempStruct = Results(i).zscored_traces';
    for iNeuron= 1: size(Neurons,2)  
        t=(Neurons(1,iNeuron));
     if ~isempty(t)
    numOfThisId = find(strcmp(IdisGlob, Neurons(1,iNeuron))==1);
    %interpolate 
    x_int = linspace(0, 1, InterpSize);
    x_orig = linspace(0, 1, size(tempStruct, 2));
    interpolated_neuron_trace = interp1(x_orig,tempStruct(iNeuron,:), x_int);
    if ~isempty(numOfThisId)
    alltraces(numOfThisId).trace = [ alltraces(numOfThisId).trace ; interpolated_neuron_trace];
    end
     else 
         continue
     end
    end
 end
% end
% eleminate empty elements corresponding to neruons IDs not found in any dataset
    iElement = 1;   
    while iElement <= size(alltraces,1)
        
        if isempty(alltraces(iElement).trace)
             alltraces(iElement) = [];
        else
            % get the average
            alltraces(iElement).Average_trace = mean(alltraces(iElement).trace,1);  
        iElement=iElement+1;
        end
    end
    %% PCA 
%    for y=1:length(alltraces) 
%        for s=1:size(alltraces(y).trace)
%        input(y).trace(:,s)= alltraces(y).trace(s,:)
%        end
%    end
%    
%     [~, score,~,~,variance_explained] = pca(input);
%% plotting
Avg_trace_matrix=[];
for x=1:length(alltraces)
Avg_trace_matrix(x, :)=alltraces(x).Average_trace;
end
% for k=1:length(allNeurons)
%  Avg_trace_matrix(k, :)=allNeurons(k).trigAveargeHit;   
% end
c_min= min(Avg_trace_matrix);
c_max= max(Avg_trace_matrix);
clim_min= min(c_min);
clim_max= max(c_max);
fig= imagesc(Avg_trace_matrix);
ax=gca;
yticks([1:size(Avg_trace_matrix,1)])
ax.YTickLabel = {alltraces.neuronName};
xticks([1000:1000:InterpSize])
ax.XTickLabel={'200','400','600','800','1000','1200','1400','1600','1800'};
% ax.YTickLabel = {allNeurons.neuronName};
% yticks([1:length(Results(i).NeuronNames)])
% ax.YTickLabel = {Results(i).NeuronNames};
xlabel('Time (s)','FontSize',20);
ylabel('Neurons','FontSize',20);

table=array2table(Avg_trace_matrix',"VariableNames",{alltraces.neuronName})
