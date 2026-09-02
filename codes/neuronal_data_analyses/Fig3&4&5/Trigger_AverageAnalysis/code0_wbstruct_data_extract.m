function Results = extract_wbstructs(mode)
% EXTRACT_WBSTRUCTS  Extract traces from wbstruct datasets (head or tail).
%
% Usage:
%   Results = extract_wbstructs('head');
%   Results = extract_wbstructs('tail');
%
% Input:
%   mode - 'head' or 'tail'
%
% Output:
%   Results struct is also saved as:
%     - WBstruct_head_data_extracted.mat
%     - WBstruct_tail_data_extracted.mat
%
% Notes:
%   - Bleach correction formula is applied
%   - Z-scored traces are also stored
%   - Only head includes traceColoring in the Results struct

%% Parameters
alpha = 0.0001;   % param for derivative regularization (if used)
iter  = 10;       % iterations for derivReg (unused here)

if nargin < 1
    error('Please specify mode: "head" or "tail".');
end

%% Search for files
switch lower(mode)
    case 'head'
        wbstructs = dir('*H_wbstruct*');
        outfile   = 'WBstruct_head_data_extracted.mat';
    case 'tail'
        wbstructs = dir('*T_wbstruct*');
        outfile   = 'WBstruct_tail_data_extracted.mat';
    otherwise
        error('Mode must be "head" or "tail".');
end

if isempty(wbstructs)
    error('No %s wbstruct files found in current directory.', mode);
end

Results = struct();

%% Process each wbstruct
for wbfile = 1:length(wbstructs)
    
    % --- Load file ---
    currFile = wbstructs(wbfile).name;
    load(currFile, 'simple');   % assumes 'simple' struct inside wbstruct
    fprintf('... loading wbstruct #%d = %s \n', wbfile, currFile);
    
    % --- Parse filename ---
    spl_file = strsplit(currFile, '_');
    
    % --- Traces (optionally use derivReg) ---
    % traceOut = derivReg(simple.deltaFOverF, alpha, iter);
    traceOut = simple.deltaFOverF;
    
    % --- Bleach correction + z-scoring ---
    traces_corrected = NaN(size(simple.deltaFOverF_bc));
    traces_zscored   = NaN(size(simple.deltaFOverF_bc));
    
    for i = 1:size(simple.deltaFOverF_bc, 2)
        n_bleach = traceOut(:, i);
        
        % Bleach correction (simple cumulative scaling)
        n_bleach = n_bleach .* (1 + (cumsum(n_bleach) / length(n_bleach)));
        traces_corrected(:, i) = n_bleach;
        
        % Z-scoring
        traces_zscored(:, i) = (n_bleach - mean(n_bleach)) / std(n_bleach);
    end
    
    % --- Store in Results struct ---
    Results(wbfile).filename              = currFile;
    Results(wbfile).date                  = spl_file{1};
    Results(wbfile).worm_number           = spl_file{2};
    Results(wbfile).fps                   = simple.fps;
    Results(wbfile).deltaFOverF           = simple.deltaFOverF;
    Results(wbfile).deltaFOverF_bc        = simple.deltaFOverF_bc;
    Results(wbfile).Bleachcorrected_traces= traces_corrected;
    Results(wbfile).zscored_traces        = traces_zscored;
    Results(wbfile).stimulus              = simple.stimulus;
    Results(wbfile).NeuronNames           = simple.ID;
    Results(wbfile).deriv_traces          = simple.derivs.traces;
    
    % Only HEAD has traceColoring
    if strcmpi(mode, 'head') && isfield(simple, 'traceColoring')
        Results(wbfile).traceColoring = simple.traceColoring;
    end
end

%% Save Output
save(outfile, 'Results');
fprintf('Extraction complete. Saved as %s\n', outfile);

end
