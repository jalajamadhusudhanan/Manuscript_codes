
function [ ] = plot_byname_2005( neuronName, allNeurons, errorBar )


% uses allNeurons structure variable to plot stim trig for a particular
% neuron; call it by its name and deifne errorBAr - std or SEM

for i = 1: size(allNeurons,2)
    if   strcmp (allNeurons(i).neuronName, neuronName )
                neuronInd = i;
    end
end


  % hfig = figure ('Position', [100 100  800 600]);
   % hfig = figure ('Position', [100 100  1200 600]);
   hfig =  figure ('Position', [100 100  800 600]);
   neuronInd 

    min_win = -60;
    max_win = 30;
        
    time = linspace(min_win,max_win,450);
    yl=[-1,1.5]
    %patch([-7 0 0 -7],[yl(1) yl(1) yl(2) yl(2)],[0.9, 0.9,0.9])
    hold on
    plot(time ,allNeurons(neuronInd).trigAveargeHit, 'LineWidth',2.5,'color',[0.9375    0.4570    0.0625]); %, [0.85 0.325 0.098]
    hold on
    plot(time, allNeurons(neuronInd).trigAveargeMiss,'LineWidth',2.5, 'color',[0    0.6875    0.9375] );%[0 0.447 0.741]
    hold on
   
        
    if strcmpi(errorBar,'SEM')
            jbfill(time, allNeurons(neuronInd).trigAveargeHit + allNeurons(neuronInd).SEMHit, allNeurons(neuronInd).trigAveargeHit - allNeurons(neuronInd).SEMHit, [0.9375    0.4570    0.0625]);
            hold on
            jbfill(time, allNeurons(neuronInd).trigAveargeMiss + allNeurons(neuronInd).SEMMiss, allNeurons(neuronInd).trigAveargeMiss - allNeurons(neuronInd).SEMMiss, [0    0.6875    0.9375]);
            hold on
    elseif strcmpi(errorBar,'Std')
        
            jbfill(time, allNeurons(neuronInd).trigAveargeHit + allNeurons(neuronInd).StdHit, allNeurons(neuronInd).trigAveargeHit - allNeurons(neuronInd).StdHit, [0.9375    0.4570    0.0625] ); %[0.85 0.325 0.098]
            hold on
            jbfill(time, allNeurons(neuronInd).trigAveargeMiss + allNeurons(neuronInd).StdMiss, allNeurons(neuronInd).trigAveargeMiss - allNeurons(neuronInd).StdMiss, [0    0.6875    0.9375] ); %[0 0.447 0.741]
            hold on
    elseif strcmpi(errorBar,'none')        
            
    else
            disp('wrong input')
    end
        
        %vline(0); 
       
        %yl = [0 3]
       % line ([0 0], [yl(1) yl(2)], 'LineWidth',1.5, 'Color', 'k','HandleVisibility','off')
        
%         vline(0); 
       %vline(-60); 
       %vline(30);
       %vline(90);
       x=[0 30 30 0];
       y=[yl(1) yl(1) abs(yl(1))+yl(2) abs(yl(1))+yl(2)];
       c=[0.9 0.9 0.9];
%        patch(x,y,c,'FaceAlpha','0.5');
%       rectangle('Position', [0 yl(1) 30 abs(yl(1))+yl(2)], 'FaceColor', [0.9 0.9 0.9], 'LineStyle', '-','EdgeColor','k','FaceAlpha','0.5'); 
       %xline(0,'LineWidth',2, 'Color', 'k','HandleVisibility','off');
       xline(0,'LineWidth',1.5,'LineStyle','--','Color','r')
       % xlim( [min_win max_win]);
        xlim( [-60 30]);
        ylim([yl(1) yl(2)])
        xlabel('Time (s)')
        ylabel('dF/F')
        hold on
        %title([allNeurons(neuronInd).neuronName,', #Response: ', num2str(size(allNeurons(neuronInd).trigHit,1)) , ', #No response: ', num2str(size (allNeurons(neuronInd).trigMiss,1))])
        title(allNeurons(neuronInd).neuronName)
        set(gca,'FontSize',20)   
       xticks([-60 -30  0  30])
       ax = gca; % Get current axes
       ax.TickDir = 'out'; % Set tick direction to outward
%         saveas(hfig,['C:\Users\Jalaja Madhusudhanan\Desktop\stimtrig_avg_neurons_plot\', allNeurons(neuronInd).neuronName ], 'tiff')
end   
        