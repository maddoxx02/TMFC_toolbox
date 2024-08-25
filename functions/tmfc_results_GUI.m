function tmfc_results_GUI(thresholded,pval,tval,conval,alpha,correction)

% In order to save TYEST TYPE & THRESHOLD TYPE WE NEED TO HAVE MORE
% VARIABLES INTO THE FUNCTION ARGUMENT PARAMETERS ---- lets check

% if nargin == 0
% 
%     file = spm_select(1,'.mat','Select folders of all subjects',{},pwd,'.');
%     if ~isempty(file)
%         tmfc_res = load(file);
%         thresholded
%         pval
%         pval
%         conval
%         alpha
%         correction = 
%         
%         disp('File Loaded');
%     else
%         warning('Please select a .mat file to visualization TMFC toolbox computed results');
%         thresholded = [];
%     end
% end

if ~isempty(thresholded)

    res_win = figure('Name','TMFC Simulation: Output','NumberTitle', 'off','Units', 'normalized', 'Position', [0.4 0.25 0.55 0.42],'Tag', 'TMFC Simulation: Output','WindowStyle', 'modal');
    ax1 = subplot(1,2,1); imagesc(conval);        subtitle('Group mean'); axis square; colorbar; caxis(tmfc_axis(conval,1));  
    ax2 = subplot(1,2,2); imagesc(thresholded);   subtitle(['p' correction '<' num2str(alpha)]); axis square; colorbar;  
    colormap(subplot(1,2,1),'turbo')  
    set(findall(gcf,'-property','FontSize'),'FontSize',16)
    res_win_title  = uicontrol(res_win,'Style','text','String', 'Results','Units', 'normalized', 'Position',[0.461 0.92 0.09 0.05],'fontunits','normalized', 'fontSize', 0.75);%, 'HorizontalAlignment','Left');

    save_data_btn = uicontrol('Style','pushbutton','String', 'Save Data','Units', 'normalized','Position',[0.18 0.05 0.210 0.054],'fontunits','normalized', 'fontSize', 0.36);
    save_plot_btn = uicontrol('Style','pushbutton','String', 'Save Plots','Units', 'normalized','Position',[0.62 0.05 0.210 0.054],'fontunits','normalized', 'fontSize', 0.36);
    set(save_data_btn,'callback', @int_data_saver)
    set(save_plot_btn ,'callback', @int_plot_saver)

    tmfc_res.threshold = thresholded;
    tmfc_res.pval = pval;
    tmfc_res.tval = tval;
    tmfc_res.conval = conval;
    tmfc_res.alpha = alpha; 
    
end
function save_stat = int_data_saver(~,~)
       
    % Ask user for Filename & location name:
    [filename_SO, pathname_SO] = uiputfile('*.mat', 'Save TMFC variable as'); %pwd
    
    % Set Flag save status to Zero, this flag is used in the future as
    % a reference to check if the Save was successful or not
    save_stat = 0;
    
    % Check if FileName or Path is missing or not available 
    if isequal(filename_SO, 0) || isequal(pathname_SO, 0)
        error('Simulation Results not saved, File name or Save Directory not selected');
    
    else
        % If all data is available
        % Construct full path: PATH + FileName
        % e.g (D:\user\matlab\ + Test.m)
        
        fullpath = fullfile(pathname_SO, filename_SO);
        
        % D receives the save status of the variable in the desingated
        % location
        save_stat = saver(fullpath);
        
        % If the variable was successfully saved then display info
        if save_stat == 1
            fprintf('Simulations results saved successfully in path: %s\n', fullpath);
        else
            fprintf('Simulation results not saved ');
        end
    end
          
end % Closing Save project Function

function save_stat = int_plot_saver(~,~)
       
    % Ask user for Filename & location name:
    [filename_SO, pathname_SO] = uiputfile('*.png', 'Save TMFC Plots as'); %pwd
    
    % Set Flag save status to Zero, this flag is used in the future as
    % a reference to check if the Save was successful or not
    save_stat = 0;
    
    % Check if FileName or Path is missing or not available 
    if isequal(filename_SO, 0) || isequal(pathname_SO, 0)
        error('Simulation results plots not saved, File name or Save Directory not selected');
    
    else
        % If all data is available
        % Construct full path: PATH + FileName
        % e.g (D:\user\matlab\ + Test.m)
        
        fullpath = fullfile(pathname_SO, filename_SO);
        
        % D receives the save status of the variable in the desingated
        % location
        save_stat = saver_plot(fullpath);
        
        % If the variable was successfully saved then display info
        if save_stat == 1
            fprintf('Simulation plots saved successfully in path: %s\n', fullpath);
        else
            fprintf('Simulation plots not saved\n');
        end
    end
          
end % Closing Save project Function



function SAVER_STAT =  saver(save_path)
% 0 - Successfull save, 1 - Failed save
    try 
        save(save_path, 'tmfc_res');
        SAVER_STAT = 1;
        % Save Success
    catch 
        SAVER_STAT = 0;
        % Save Fail 
    end
end

function SAVER_STAT =  saver_plot(save_path)
% 0 - Successfull save, 1 - Failed save
  
    try
        temp_res_win = figure('NumberTitle', 'off','Units', 'normalized', 'Position', [0.4 0.25 0.55 0.42],'Tag', 'TEMP TMFC Simulation: Output','visible', 'off');%,'WindowStyle', 'modal');
        temp_ax1 = subplot(1,2,1); imagesc(conval);        subtitle('Group mean'); axis square; colorbar; caxis(tmfc_axis(conval,1));  
        temp_ax2 = subplot(1,2,2); imagesc(thresholded);   subtitle(['p' correction '<' num2str(alpha)]); axis square; colorbar;  
        colormap(subplot(1,2,1),'turbo')  
        set(findall(gcf,'-property','FontSize'),'FontSize',16)
        saveas(temp_res_win,save_path);
        delete(temp_res_win);
        SAVER_STAT = 1;
    catch
        SAVER_STAT = 0;
        warning('Fatal error, file not saved');
    end
    
end


end