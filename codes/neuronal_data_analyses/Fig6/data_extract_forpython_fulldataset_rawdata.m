%data preparation for PCA LDA model in python
load('allNeurons_Avg_stimtrig_hit&miss.mat', 'allNeurons');
frame_rate=450/90;
total_length=1890*frame_rate;
numDat = 9;
trials=16;
count_dataset=[];list=char(); neuron_id=[];
AIB_Hit = allNeurons(1).IndHit(:,1);AIB_Miss = allNeurons(1).IndMiss(:,1);
groups=[];

for i=1:length(allNeurons)
    neuron=allNeurons(i).neuronName;
    count_dataset(i,1)=(size(allNeurons(i).trigHit,1)+size(allNeurons(i).trigMiss,1))/(size(AIB_Hit,1)+size(AIB_Miss,1));
    if count_dataset(i,1)>=0.5
        list=char(list,neuron);
    end
end
list=list(2:end,:); 
neurons_selected=cellstr(list)';
load('Alldataset_data_extracted.mat','All_neuron_data')
data_table=[];
for dat=1:numDat
    data_series=[];neuron=[];neurons=[];response=[];state_trace=[];
for j=1:length(neurons_selected)
    trace_final=[];
    neuron=convert_cells_to_char(neurons_selected(j));
    neurons=convert_cells_to_char(All_neuron_data(dat).NeuronNames);
    neuron_id=find(ismember(neurons,neuron)==1)
    if ~isempty(neuron_id)
        trace=All_neuron_data(dat).deltaFOverF_bc(:,neuron_id)';
        %%%interpolation
        x_int = linspace(0,1, total_length);
        x_orig = linspace(0, 1, size(trace,2));
        trace_final = interp1(x_orig,trace, x_int); 
    else
        trace_final = NaN(total_length,1);      
    end
    data_series(1:total_length,j)=trace_final;   
end
response=All_neuron_data(dat).Response';
state_trace=All_neuron_data(dat).behaviour_annotation;
group=dat*ones(total_length,1);
%%%interpolation
target = round(interp1(x_orig,response, x_int)); 
state= round(interp1(x_orig,state_trace, x_int)); 
data=[data_series,target',state',group];

data_table=[data_table;data];
end
table=array2table(data_table,"VariableNames",strcat({neurons},'state','group'))