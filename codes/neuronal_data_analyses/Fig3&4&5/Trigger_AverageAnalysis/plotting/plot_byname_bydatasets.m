 
function [ ] = plot_byname_bydatasets( neuronName, allNeurons, errorBar )

%Plots trig averages for a particular neuron for each dataset separately

numDat = 9; %amount of datasets in the set

for i = 1: size(allNeurons,2)
    if   strcmp (allNeurons(i).neuronName, neuronName )
                neuronInd =i;
    end
end

    hfig =  figure ('Position', [100 100  2000 400]);
    
    min_win = -60;
    max_win = 30;
        
    time = linspace(min_win,max_win,300);
     
    fd = 2;
    sd = 5;
    
%     plotVar = ['ax1', 'ax2', 'ax3', 'ax4', 'ax5']
    for datI = 1:numDat
      
        IndexHit = allNeurons(neuronInd).IndHit(:,1);
        IndToMeanHit = find(IndexHit == datI);
        
        IndexMiss = allNeurons(neuronInd).IndMiss(:,1);
        IndToMeanMiss = find(IndexMiss == datI);
        
        whatToMeanHit = allNeurons(neuronInd).trigHit( IndToMeanHit ,:);
        whatToMeanMiss = allNeurons(neuronInd).trigMiss( IndToMeanMiss ,:);
        
        trigHitMean = mean ( whatToMeanHit,1);
        trigMissMean = mean ( whatToMeanMiss,1);
        
        trigHitStd = std( whatToMeanHit,1);
        trigHitSem = std( whatToMeanHit,1)/sqrt( size( whatToMeanHit,1));
        
        trigMissStd = std( whatToMeanMiss,1);
        trigMissSem = std( whatToMeanMiss,1)/sqrt( size( whatToMeanMiss,1));
        
         subplot(fd,sd,datI );
        
        %figure;
        plot(time ,trigHitMean, 'LineWidth',1.5,'color','r'); %, [0.85 0.325 0.098]
        hold on
        plot(time, trigMissMean,'LineWidth',1.5, 'color','b' );%[0 0.447 0.741]
        hold on
        
        if strcmpi(errorBar,'SEM')
                jbfill(time, trigHitMean + trigHitSem , trigHitMean - trigHitSem, 'r');
                hold on
                jbfill(time, trigMissMean + trigMissSem, trigMissMean - trigMissSem, 'b');
                hold on
        elseif strcmpi(errorBar,'Std')

                jbfill(time, trigHitMean + trigHitStd, trigHitMean -trigHitStd , 'r' ); %[0.85 0.325 0.098]
                hold on
                jbfill(time, trigMissMean +trigMissStd , trigMissMean - trigMissStd, 'b' ); %[0 0.447 0.741]
                hold on
        elseif strcmpi(errorBar,'none')        

        else
                disp('wrong input')
        end

           mygca(datI) = gca;
            ylTemp =ylim;
              xline(0,'LineWidth',2, 'Color', 'k','HandleVisibility','off');
%            ylimVal = [0 6];
           line([0 0], ylTemp, 'LineWidth',1.5, 'Color', 'k','HandleVisibility','off'); 
%            rectangle('Position', [0 0 30 ymax], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor','k');

           % xlim( [min_win max_win]);
            xlim( [-60 30]);
            %ylim([yl(1) yl(2)])
%             ylim([ylimVal])
            xlabel('time (sec)')
            ylabel('dF/F (z-score)')
            %xticks([-30 -30  0  30])
            title([allNeurons(neuronInd).neuronName,'dat#',num2str(datI), ', #hit: ', num2str(size(whatToMeanHit,1)) , ', #miss: ', num2str(size (whatToMeanMiss,1))])
            set(gca,'FontSize',10) 

           
    end
     
    yl = cell2mat(get(mygca, 'Ylim'));
    ylnew = [ min(yl(:,1)) max( yl(:,2))];
    set( mygca, 'Ylim', ylnew)  
    saveas(hfig,['C:\Users\Jalaja Madhusudhanan\Desktop\stimtrig_avg_bydataset_plot\', allNeurons(neuronInd).neuronName], 'tiff')
    
end  