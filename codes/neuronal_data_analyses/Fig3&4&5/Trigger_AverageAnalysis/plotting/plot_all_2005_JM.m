function [ ] = plot_all_2005_JM( allNeurons, errorBar )
        min_win = -60;
        max_win = 30;
        InterpSize = length(allNeurons(1).trigHit); %adjust according to your recording
    % Plot 
    %hfig = figure ('Position', [50 50 5000 2200]);%[50 50 2200 1200]
    tiledlayout(9,10, 'Padding', 'none', 'TileSpacing', 'compact');
    allNeurons = allNeurons;
    
    for j = 1: size(allNeurons,2)

        fd = 10;
        sd = ceil(size(allNeurons,2)/fd);
        nexttile
        %subplot(fd,sd,j);
         
        time = linspace(min_win,max_win,InterpSize);
        
        plot(time ,allNeurons(j).trigAveargeHit, 'LineWidth',1.5,'color', [0.9375    0.4570    0.0625]); %, 'Color',[0.8 0 0]); % [0.9100    0.4100    0.1700]
        hold on
        plot(time, allNeurons(j).trigAveargeMiss,'LineWidth',1.5, 'color',[0    0.6875    0.9375] );
        hold on
        
        if strcmpi(errorBar,'SEM')
            jbfill(time, allNeurons(j).trigAveargeHit + allNeurons(j).SEMHit, allNeurons(j).trigAveargeHit - allNeurons(j).SEMHit,[0.9375    0.4570    0.0625]);
            hold on
            jbfill(time, allNeurons(j).trigAveargeMiss + allNeurons(j).SEMMiss, allNeurons(j).trigAveargeMiss - allNeurons(j).SEMMiss, [0    0.6875    0.9375]);
            hold on
        elseif strcmpi(errorBar,'Std')
        
            jbfill(time, allNeurons(j).trigAveargeHit + allNeurons(j).StdHit, allNeurons(j).trigAveargeHit - allNeurons(j).StdHit, 'r');
            hold on
            jbfill(time, allNeurons(j).trigAveargeMiss + allNeurons(j).StdMiss, allNeurons(j).trigAveargeMiss - allNeurons(j).StdMiss, 'b');
            hold on
        elseif strcmpi(errorBar,'none')
            
        else
            disp('wrong input')
        end
        
       
        
%          ylim( [ 0 6]);
        xlim( [ min_win max_win]);
        %xlim( [ -20 20]);
         xline(0,'LineWidth',1, 'Color', 'k'); 
%        xline(-30);
       % xline(-60); 
        %xline(0);
        %xline(30);
%         vline(90);
        title([allNeurons(j).neuronName,' hits:', num2str(size(allNeurons(j).trigHit,1)) , 'misses:', num2str(size (allNeurons(j).trigMiss,1))],'FontSize',8);
         %title([allNeurons(j).neuronName],'FontSize',10);
        
        %title( num2str(size(allNeurons(j).trigHit,1)) )
        
%         supertitle('Hit&Miss Analysis 9 datasets AVAlowtrials(stim trig)' );
   
    end
%     savefig (hfig, 'hit&miss_AVAlow_stimstrig plot');
%     saveas(hfig, 'hit&miss_AVAlow_stimtrig plot','png')
end
       %% for restrig
    
function [ ] = plot_all_2005_JM( allNeurons, errorBar )
        min_win = -30;
        max_win = 30;
        InterpSize = length(allNeurons(1).trigHit); %adjust according to your recording
    excludeNeurons = {'URXL','URXR','AQR','PQR','AUAL','AUAR','RMGL','RMGR','PVPL','PVPR','IL2L','IL2R','BAGL','BAGR'};
        % Plot 
    fig = figure;

    set(fig,'Units','centimeters')
    set(fig,'Position',[2 2 20 19.8])   % width × height

    set(fig,'PaperUnits','centimeters')
    set(fig,'PaperSize',[21 29.7])
    set(fig,'PaperPosition',[0.5 5 20 19.8])     % centered vertically

    %hfig = figure ('Position', [50 50 5000 2200]);%[50 50 2200 1200]
    tiledlayout(9,8, 'Padding', 'compact', 'TileSpacing', 'compact');
    allNeurons = allNeurons;
    
    for j = 1: size(allNeurons,2)

        fd = 6;
        sd = ceil(size(allNeurons,2)/fd);
        if ismember(allNeurons(j).neuronName,excludeNeurons)
            continue
        end

        nexttile
        %subplot(fd,sd,j);
        
        time = linspace(min_win,max_win,InterpSize);
        
        hold on
        

        if strcmpi(errorBar,'SEM')
            jbfill(time, allNeurons(j).trigAveargeHit + allNeurons(j).SEMHit, allNeurons(j).trigAveargeHit - allNeurons(j).SEMHit,'k');
            hold on
            jbfill(time, allNeurons(j).trigAveargeMiss + allNeurons(j).SEMMiss, allNeurons(j).trigAveargeMiss - allNeurons(j).SEMMiss,'b');
            hold on
        elseif strcmpi(errorBar,'Std')
        
            jbfill(time, allNeurons(j).trigAveargeHit + allNeurons(j).StdHit, allNeurons(j).trigAveargeHit - allNeurons(j).StdHit, 'r');
            hold on
            jbfill(time, allNeurons(j).trigAveargeMiss + allNeurons(j).StdMiss, allNeurons(j).trigAveargeMiss - allNeurons(j).StdMiss, 'b');
            hold on
        elseif strcmpi(errorBar,'none')
            
        else
            disp('wrong input')
        end
        yl = ylim;        % get final limits
        ylim(yl)          % lock them
        hold on
        % --- Plot traces ---
        plot(time, allNeurons(j).trigAveargeHit, ...
    'LineWidth',1.5,'Color','k');
        hold on

        plot(time, allNeurons(j).trigAveargeMiss, ...
    'LineWidth',1.5,'Color','b');
%         p = patch([-7 30 30 0], ...
%           [yl(1) yl(1) yl(2) yl(2)], ...
%           [0.9 0.9 0.9], ...
%           'EdgeColor','none', ...
%           'FaceAlpha',1);
% 
%         uistack(p,'bottom')
        xlim( [ min_win max_win]);
        %xlim( [ -20 20]);
         xline(0,'LineWidth',1, 'Color', 'r','LineStyle','--'); 
%        xline(-30);
       % xline(-60); 
        %xline(0);
        %xline(30);
%         vline(90);
%         title([allNeurons(j).neuronName,'(', num2str(size(allNeurons(j).trigHit,1)) , '/', num2str(size (allNeurons(j).trigMiss,1)),'), N=',num],'FontSize',8);
         title([allNeurons(j).neuronName],'FontSize',10);
        
        %title( num2str(size(allNeurons(j).trigHit,1)) )
        
%         supertitle('Hit&Miss Analysis 9 datasets AVAlowtrials(res trig)' );
   
    end
%     savefig (hfig, 'hit&miss_AVAlow_restrig plot');
%     saveas(hfig, 'hit&miss_AVAlow_restrig plot','png')
end