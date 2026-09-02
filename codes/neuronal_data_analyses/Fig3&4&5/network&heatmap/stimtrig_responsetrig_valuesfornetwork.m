load('allNeurons_Avg_stimtrig_hit&miss.mat')
% load('allNeurons_Avg_restrig_hit&miss.mat')
trig_matrix=[];delta=[];
fps=5;
for i=1:length(allNeurons)
    neuron=allNeurons(i).neuronName;
    %one way
    trig_matrix=[allNeurons(i).trigHit;allNeurons(i).trigMiss];
    trig_avg=mean(trig_matrix);
    smoothed_avg=smoothdata(trig_avg,10,'movmean')
    minimum_value(i)=min(smoothed_avg(30*fps:end));
    maximum_value(i)=max(smoothed_avg(30*fps:end)); 
    delta(i,1)= maximum_value(i)-minimum_value(i);   
end

% % chat 
numNeurons = length(allNeurons);
numCols = ceil(sqrt(numNeurons)); % Define number of columns in the grid
numRows = ceil(numNeurons / numCols); % Define number of rows in the grid

% figure;
tiledlayout(numRows, numCols, 'TileSpacing', 'tight', 'Padding', 'compact');

for i = 49%1:numNeurons
    neuron = allNeurons(i).neuronName;  % Extract neuron name
    trig_matrix = [allNeurons(i).trigHit;allNeurons(i).trigMiss];  % Get data
    trig_avg = mean(trig_matrix, 1);  % Compute mean across trials
    sem = std(trig_matrix)/sqrt(size(trig_matrix, 1)); % Compute SEM
    smoothed_avg = smoothdata(trig_avg(151:end), 'movmean', 10);
    smoothed_sem = smoothdata(sem(151:end), 'movmean', 10);  % Smooth SEM for visualization
    
    % Get min/max values after 60 sec mark
%     minimum_value(i) = min(smoothed_avg(60 * fps:end));
%     maximum_value(i) = max(smoothed_avg(60 * fps:end)); 
%     delta(i,1) = maximum_value(i) - minimum_value(i);  
    
    % Prepare x-axis
    time = linspace(-30,30,300);
    
    % Plot each neuron's smoothed average with SEM
%     nexttile;
%     hold on;
    figure()
    % Fill the SEM area using jbfill (lower and upper bounds)
    jbfill(time, smoothed_avg + smoothed_sem, smoothed_avg - smoothed_sem,'k'); % Light blue fill
    hold on
    % Plot smoothed average trace
    plot(time, smoothed_avg, 'k', 'LineWidth', 1.5);
    xline(0,'LineWidth',1.5,'LineStyle','--','Color','r')
    ylim( [-1 1]);
    xlim( [-30 30]);
    title(neuron, 'Interpreter', 'none');    
        xlabel('Time (s)')
        ylabel('dF/F')
    
    hold off;
end

%%
% Define neuron order
desired_order = {
    'URXL','IL2L','RMGL','AUAL','AQR','RIS','PQR', ...
    'PVPL','ALA','BAGL','RID', ...
    'ASKL','AVBL','SMDDL','SMDVL','RIBL','RIVL','DVA','PVNL', ...
    'ALNR','AVAL','AIBL','RIML','AVEL'};

% Load .mat file
[filename, pathname] = uigetfile('*.mat', 'Select neuron data file');
if isequal(filename, 0)
    error('No file selected.');
end
load(fullfile(pathname, filename));

% Determine mode
isStimTrig = contains(filename, 'stimtrig');
suffix = ternary(isStimTrig, 'stimtrig', 'restrig');

% Prepare
allNames = {allNeurons.neuronName};
[~, original_order] = ismember(desired_order, allNames);
fps = 5;
time = linspace(-30, 30, 300);

for plot_idx = 1:length(original_order)
    i = original_order(plot_idx);
    if i == 0
        warning('Neuron %s not found.', desired_order{plot_idx});
        continue;
    end

    neuron = allNeurons(i).neuronName;

    % Choose data
    if isStimTrig
        trig_matrix = [allNeurons(i).trigHit; allNeurons(i).trigMiss];
        trig_avg = mean(trig_matrix, 1);
        sem = std(trig_matrix) / sqrt(size(trig_matrix, 1));
        smoothed_avg = smoothdata(trig_avg(151:end), 'movmean', 10);
        smoothed_sem = smoothdata(sem(151:end), 'movmean', 10);
    else
        trig_matrix = allNeurons(i).trigMiss;
        trig_avg = mean(trig_matrix, 1);
        sem = std(trig_matrix) / sqrt(size(trig_matrix, 1));
        smoothed_avg = smoothdata(trig_avg, 'movmean', 10);
        smoothed_sem = smoothdata(sem, 'movmean', 10);
    end

    % Plot
    figure('Visible', 'off');
    hold on;
    jbfill(time, smoothed_avg + smoothed_sem, smoothed_avg - smoothed_sem, [0.5 0.5 0.5]);
    hold on
    plot(time, smoothed_avg, 'k', 'LineWidth', 1.5);
    xline(0, 'r--', 'LineWidth', 1.5);
    ylim([-1 3]);
    xlim([-30 30]);
    xlabel('Time (s)');
    ylabel('dF/F');
    title(neuron, 'Interpreter', 'none');
    box off;  % <--- Remove box

    % Save
    print(sprintf('%s_%s.svg', neuron, suffix), '-dsvg', '-painters');
    close(gcf);
end

% Helper ternary function
function out = ternary(cond, valTrue, valFalse)
    if cond
        out = valTrue;
    else
        out = valFalse;
    end
end

  