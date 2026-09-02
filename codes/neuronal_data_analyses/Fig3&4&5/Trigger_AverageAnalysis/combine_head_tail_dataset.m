
All_neuron_data=struct();
num_datasets=9;
for i=1:num_datasets
load('WBstruct_head_data_extracted.mat')
All_neuron_data(i).filename=Results(i).filename;
All_neuron_data(i).fps=Results(i).fps;
All_neuron_data(i).Bleachcorrected_traces= Results(i).Bleachcorrected_traces;
All_neuron_data(i).deltaFOverF= Results(i).deltaFOverF;
All_neuron_data(i).deltaFOverF_bc= Results(i).deltaFOverF_bc;
 All_neuron_data(i).deriv_traces= Results(i).deriv_traces;
 All_neuron_data(i).zscored_traces=Results(i).zscored_traces;
All_neuron_data(i).NeuronNames=Results(i).NeuronNames;
All_neuron_data(i).States=Results(i).states;
load('WBstruct_tail_data_extracted.mat')
All_neuron_data(i).Bleachcorrected_traces=[All_neuron_data(i).Bleachcorrected_traces, Results(i).Bleachcorrected_traces];
All_neuron_data(i).NeuronNames=[All_neuron_data(i).NeuronNames, Results(i).NeuronNames];
All_neuron_data(i).deltaFOverF= [All_neuron_data(i).deltaFOverF,Results(i).deltaFOverF];
All_neuron_data(i).deltaFOverF_bc=[All_neuron_data(i).deltaFOverF_bc, Results(i).deltaFOverF_bc];
 All_neuron_data(i).deriv_traces= [All_neuron_data(i).deriv_traces, Results(i).deriv_traces];
 All_neuron_data(i).zscored_traces=  [All_neuron_data(i).zscored_traces,Results(i).zscored_traces];
end
str=strcat('Alldataset_data_extracted');
save(str, 'All_neuron_data')

