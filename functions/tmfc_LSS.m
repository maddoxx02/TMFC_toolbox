function [sub_check] = tmfc_LSS(tmfc,start_sub)

% ========= Task-Modulated Functional Connectivity (TMFC) toolbox =========
%
% For each individual trial, the Least-Squares Separate (LSS) approach
% estimates a separate GLM with two regressors. The first regressor models
% the expected BOLD response to the current trial of interest, and the 
% second (nuisance) regressor models the BOLD response to all other trials
% (of interest and no interest). For trials of no interest (e.g., errors),
% individual GLMs are not estimated. Trials of no interest are used only
% for the second (nuisance) regressor.
%
% This function uses SPM.mat file (which contains the specification of the
% 1st-level GLM with canonical HRF) to specify and estimate 1st-level GLMs
% for each individual trial of interest (LSS approach).
%
% FORMAT [sub_check] = tmfc_LSS(tmfc)
% Run a function starting from the first subject in the list.
%
%   tmfc.subjects.path     - Paths to individual SPM.mat files
%   tmfc.project_path      - Path where all results will be saved
%   tmfc.defaults.parallel - 0 or 1 (sequential or parallel computing)
%   tmfc.defaults.maxmem   - e.g. 2^31 = 2GB (how much RAM can be used at
%                            the same time during GLM estimation)
%   tmfc.defaults.resmem   - true or false (store temporaty files during
%                            GLM estimation in RAM or on disk)
%
%   tmfc.LSS.conditions        - List of conditions of interest
%   tmfc.LSS.conditions.sess   - Session number (as specified in SPM.Sess)
%   tmfc.LSS.conditions.number - Condition number (as specified in SPM.Sess.U)
%
% Session number and condition number must match the original SPM.mat file.
% Consider, for example, a task design with two sessions. Both sessions 
% contains three task regressors for "Cond A", "Cond B" and "Errors". If
% you are only interested in comparing "Cond A" and "Cond B", the following
% structure must be specified:
%
%   tmfc.LSS.conditions(1).sess   = 1;   
%   tmfc.LSS.conditions(1).number = 1; - "Cond A", 1st session
%   tmfc.LSS.conditions(2).sess   = 1;
%   tmfc.LSS.conditions(2).number = 2; - "Cond B", 1st session
%   tmfc.LSS.conditions(3).sess   = 2;
%   tmfc.LSS.conditions(3).number = 1; - "Cond A", 2nd session
%   tmfc.LSS.conditions(4).sess   = 2;
%   tmfc.LSS.conditions(4).number = 2; - "Cond B", 2nd session
%
% FORMAT [sub_check] = tmfc_LSS(tmfc, start_sub)
% Run the function starting from а specific subject in the path list.
%
%   tmfc                   - As above
%   start_sub              - Subject number on the path list to start with
%
% =========================================================================
%
% Copyright (C) 2023 Ruslan Masharipov
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program. If not, see <https://www.gnu.org/licenses/>.
%
% Contact email: masharipov@ihb.spb.ru


if nargin == 1
   start_sub = 1;
end

try
    main_GUI = guidata(findobj('Tag','TMFC_GUI'));                           
    set(main_GUI.TMFC_GUI_S6,'String', 'Updating...','ForegroundColor',[0.772, 0.353, 0.067]);       
end

spm('defaults','fmri');
spm_jobman('initcfg');

N = length(tmfc.subjects);

cond_list = tmfc.LSS.conditions;
sess = []; sess_num = []; N_sess = [];
for i = 1:length(cond_list)
    sess(i) = cond_list(i).sess;
end
sess_num = unique(sess);
N_sess = length(sess_num);

EXIT_STATUS_LSS = 0;

% Initialize waitbar for sequential or parallel computing
switch tmfc.defaults.parallel
    case 0
        handles = waitbar(0,'Please wait...','Name','LSS regression','Tag','tmfc_waitbar');
        cleanupObj = onCleanup(@cleanMeUp);
    case 1
        try
            parpool
        end
        handles = waitbar(0,'Please wait...','Name','LSS regression','Tag','tmfc_waitbar');
        %D = parallel.pool.DataQueue;                                        % Creation of Parallel Pool 
        %afterEach(D, @tmfc_parfor_waitbar);                                 % Command to update Waitbar
        tmfc_parfor_waitbar(handles, N);     
        cleanupObj = onCleanup(@cleanMeUp);

        try % Bring TMFC main window to the front 
            figure(findobj('Tag','TMFC_GUI'));
        end
end

% Loop through subjects
for i = start_sub:N
    tic

    if EXIT_STATUS_LSS == 1 
        delete(handles);
        break;
    end
    
    SPM = load(tmfc.subjects(i).path);
    
    if isdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')]))
        rmdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')]),'s');
    end

    if ~isdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')]))
        mkdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],'Betas'));
        mkdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],'GLM_batches'));
    end

    % Loop through sessions
    for j = 1:N_sess       
        
        if EXIT_STATUS_LSS == 1 
            break;
        end
        
        % Trials of interest
        E = 0;
        ons_of_int = [];
        dur_of_int = [];
        cond_of_int = [];
        trial.cond = [];
        trial.number = [];
        for k = 1:length(cond_list)
            if cond_list(k).sess == sess_num(j)
                E = E + length(SPM.SPM.Sess(sess_num(j)).U(cond_list(k).number).ons);
                ons_of_int = [ons_of_int; SPM.SPM.Sess(sess_num(j)).U(cond_list(k).number).ons];
                dur_of_int = [dur_of_int; SPM.SPM.Sess(sess_num(j)).U(cond_list(k).number).dur];
                cond_of_int = [cond_of_int cond_list(k).number];
                trial.cond = [trial.cond; repmat(cond_list(k).number,length(SPM.SPM.Sess(sess_num(j)).U(cond_list(k).number).ons),1)];
                trial.number = [trial.number; (1:length(SPM.SPM.Sess(sess_num(j)).U(cond_list(k).number).ons))'];
            end
        end

        all_trials_number = (1:E)';  

        % Trials of no interest
        cond_of_no_int = setdiff((1:length(SPM.SPM.Sess(sess_num(j)).U)),cond_of_int);
        ons_of_no_int = [];
        dur_of_no_int = [];
        for k = 1:length(cond_of_no_int)
            ons_of_no_int = [ons_of_no_int; SPM.SPM.Sess(sess_num(j)).U(cond_of_no_int(k)).ons];
            dur_of_no_int = [dur_of_no_int; SPM.SPM.Sess(sess_num(j)).U(cond_of_no_int(k)).dur];
        end
        
        % Loop through trials of interest
        for k = 1:E

            if isdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],['LSS_Sess_' num2str(sess_num(j)) '_Trial_' num2str(k)]))
                rmdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],['LSS_Sess_' num2str(sess_num(j)) '_Trial_' num2str(k)]),'s');
            end
                   
            matlabbatch{1}.spm.stats.fmri_spec.dir = {fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],['LSS_Sess_' num2str(sess_num(j)) '_Trial_' num2str(k)])};
            matlabbatch{1}.spm.stats.fmri_spec.timing.units = SPM.SPM.xBF.UNITS;
            matlabbatch{1}.spm.stats.fmri_spec.timing.RT = SPM.SPM.xY.RT;
            matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = SPM.SPM.xBF.T;
            matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = SPM.SPM.xBF.T0;
                        
            % Functional images
            for image = 1:SPM.SPM.nscan(sess_num(j))
                matlabbatch{1}.spm.stats.fmri_spec.sess.scans{image,1} = SPM.SPM.xY.VY(SPM.SPM.Sess(sess_num(j)).row(image)).fname;
            end
    
            % Current trial vs all other trials (of interest and no interrest)
            current_trial_ons = ons_of_int(k);
            current_trial_dur = dur_of_int(k);
            other_trials = all_trials_number(all_trials_number~=k);
            other_trials_ons = [ons_of_int(other_trials); ons_of_no_int];
            other_trials_dur = [dur_of_int(other_trials); dur_of_no_int];
            
            % Conditions
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(1).name = 'Current_trial';
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(1).onset = current_trial_ons;
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(1).duration = current_trial_dur;
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(1).tmod = 0;
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(1).pmod = struct('name', {}, 'param', {}, 'poly', {});
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(1).orth = 1;
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(2).name = 'Other_trials';
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(2).onset = other_trials_ons;
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(2).duration = other_trials_dur;
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(2).tmod = 0;
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(2).pmod = struct('name', {}, 'param', {}, 'poly', {});
            matlabbatch{1}.spm.stats.fmri_spec.sess.cond(2).orth = 1;

            % Confounds       
            for conf = 1:length(SPM.SPM.Sess(sess_num(j)).C.name)
                matlabbatch{1}.spm.stats.fmri_spec.sess.regress(conf).name = SPM.SPM.Sess(sess_num(j)).C.name{1,conf};
                matlabbatch{1}.spm.stats.fmri_spec.sess.regress(conf).val = SPM.SPM.Sess(sess_num(j)).C.C(:,conf);
            end   

            matlabbatch{1}.spm.stats.fmri_spec.sess.multi = {''};
            matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg = {''};
    
            % HPF, HRF, mask 
            matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = SPM.SPM.xX.K(sess_num(j)).HParam;    
            matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
            matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
            matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
            matlabbatch{1}.spm.stats.fmri_spec.global = SPM.SPM.xGX.iGXcalc;
            matlabbatch{1}.spm.stats.fmri_spec.mthresh = SPM.SPM.xM.gMT;           
            
            try
                matlabbatch{1}.spm.stats.fmri_spec.mask = {SPM.SPM.xM.VM.fname};
            catch
                matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
            end
            
            if strcmp(SPM.SPM.xVi.form,'i.i.d')
                matlabbatch{1}.spm.stats.fmri_spec.cvi = 'None';
            elseif strcmp(SPM.SPM.xVi.form,'AR(0.2)')
                matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';
            else
                matlabbatch{1}.spm.stats.fmri_spec.cvi = 'FAST';
            end

            matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = {fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],['LSS_Sess_' num2str(sess_num(j)) '_Trial_' num2str(k)],'SPM.mat')};
            matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
            matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

            batch{k} = matlabbatch;
            clear matlabbatch current* other*
        end

        % Variable to exit LSS regression during execution
         
        % Sequential or parallel computing
        switch tmfc.defaults.parallel                                 
            % -------------------- Sequential Computing -----------------------
            case 0
                for k = 1:E
                    if EXIT_STATUS_LSS ~= 1                                             % IF Cancel/X button has NOT been pressed, then contiune execution
                        try
                            % Specify LSS GLM
                            spm('defaults','fmri');
                            spm_jobman('initcfg');
                            spm_get_defaults('cmdline',true);
                            spm_get_defaults('stats.resmem',tmfc.defaults.resmem);
                            spm_get_defaults('stats.maxmem',tmfc.defaults.maxmem);
                            spm_get_defaults('stats.fmri.ufp',1);
                            spm_jobman('run',batch{k});
    
                            % Save individual trial beta image
                            copyfile(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],['LSS_Sess_' num2str(sess_num(j)) '_Trial_' num2str(k)],'beta_0001.nii'),...
                                fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],'Betas', ...
                                ['Beta_[Sess_' num2str(sess_num(j)) ']_[Cond_' num2str(trial.cond(k)) ']_[' regexprep(char(SPM.SPM.Sess(sess_num(j)).U(trial.cond(k)).name),' ','_') ']_[Trial_' num2str(trial.number(k)) '].nii']));
    
                            % Save GLM_batch.mat file
                            tmfc_parsave_batch(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],'GLM_batches',...
                                ['GLM_[Sess_' num2str(sess_num(j)) ']_[Cond_' num2str(trial.cond(k)) ']_[' regexprep(char(SPM.SPM.Sess(sess_num(j)).U(trial.cond(k)).name),' ','_') ']_[Trial_' num2str(trial.number(k)) '].mat']),batch{k});
    
                            % Remove temporal LSS directory
                            rmdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],['LSS_Sess_' num2str(sess_num(j)) '_Trial_' num2str(k)]),'s');
                            
                            pause(0.01)
    
                            condition(trial.cond(k)).trials(trial.number(k)) = 1;
                        catch
                            condition(trial.cond(k)).trials(trial.number(k)) = 0;
                        end
                    else
                        waitbar(N,handles, sprintf('Cancelling Operation'));
                        delete(handles);
                        try                                                             % Updating the TMFC GUI window with the progress
                            main_GUI = guidata(findobj('Tag','TMFC_GUI'));                         % Finding the GUI's object via handle
                            set(main_GUI.TMFC_GUI_S6,'String', strcat(num2str(i), '/', num2str(N), ' done'),'ForegroundColor',[0.219, 0.341, 0.137]);    % Assigning the status to the TMFC varaible
                        end
                        break;
                    end
                end
            % --------------------- Parallel Computing ------------------------        
            case 1
                parfor k = 1:E
                    try
                        % Specify LSS GLM
                        spm('defaults','fmri');
                        spm_jobman('initcfg');
                        spm_get_defaults('cmdline',true);
                        spm_get_defaults('stats.resmem',tmfc.defaults.resmem);
                        spm_get_defaults('stats.maxmem',tmfc.defaults.maxmem);
                        spm_get_defaults('stats.fmri.ufp',1);
                        spm_jobman('run',batch{k});

                        % Save individual trial beta image
                        copyfile(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],['LSS_Sess_' num2str(sess_num(j)) '_Trial_' num2str(k)],'beta_0001.nii'),...
                            fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],'Betas', ...
                            ['Beta_[Sess_' num2str(sess_num(j)) ']_[Cond_' num2str(trial.cond(k)) ']_[' regexprep(char(SPM.SPM.Sess(sess_num(j)).U(trial.cond(k)).name),' ','_') ']_[Trial_' num2str(trial.number(k)) '].nii']));

                        % Save GLM_batch.mat file
                        tmfc_parsave_batch(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],'GLM_batches',...
                            ['GLM_[Sess_' num2str(sess_num(j)) ']_[Cond_' num2str(trial.cond(k)) ']_[' regexprep(char(SPM.SPM.Sess(sess_num(j)).U(trial.cond(k)).name),' ','_') ']_[Trial_' num2str(trial.number(k)) '].mat']),batch{k});

                        % Remove temporal LSS directory
                        rmdir(fullfile(tmfc.project_path,'LSS_regression',['Subject_' num2str(i,'%04.f')],['LSS_Sess_' num2str(sess_num(j)) '_Trial_' num2str(k)]),'s');
                        
                        trials(k) = 1;
                    catch
                        trials(k) = 0;
                    end
                    
                end

                for k = 1:E
                    condition(trial.cond(k)).trials(trial.number(k)) = trials(k);
                end
                clear trials
        end

        sub_check(i).session(sess_num(j)).condition = condition;

        clear E ons* dur* cond_of_int cond_of_no_int trial all_trials_number condition 

    end
    
    % Update waitbar for sequential or parallel computing
    switch(tmfc.defaults.parallel)
        case 0
            t = seconds(toc*(N-i)); t.Format = 'hh:mm:ss';
            try
                waitbar(double(i)/double(N),handles,[num2str(double(i)/double(N)*100,'%.f') '%, ' char(t) ' [hr:min:sec] remaining']);
            end

            try                                                             % Updating the TMFC GUI window with the progress
                main_GUI = guidata(findobj('Tag','TMFC_GUI'));                         % Finding the GUI's object via handle
                set(main_GUI.TMFC_GUI_S6,'String', strcat(num2str(i), '/', num2str(N), ' done'),'ForegroundColor',[0.219, 0.341, 0.137]);    % Assigning the status to the TMFC varaible
            end
        case 1
            send(D,[]); 
            try                                                             % Updating the TMFC GUI window with the progress
                main_GUI = guidata(findobj('Tag','TMFC_GUI'));                         % Finding the GUI's object via handle
                set(main_GUI.TMFC_GUI_S6,'String', strcat(num2str(i), '/', num2str(N), ' done'),'ForegroundColor',[0.219, 0.341, 0.137]);    % Assigning the status to the TMFC varaible
            end
    end

    clear SPM batch

end

try
    delete(handles);
end


function quitter(~,~)                                                  % Function that changes the state of execution when CANCEL is pressed
    EXIT_STATUS_LSS = 1;
end

function cleanMeUp()
    
    try
        GUI = guidata(findobj('Tag','TMFC_GUI')); 
        set([GUI.TMFC_GUI_B1, GUI.TMFC_GUI_B2, GUI.TMFC_GUI_B3, GUI.TMFC_GUI_B4,...
            GUI.TMFC_GUI_B5a, GUI.TMFC_GUI_B5b, GUI.TMFC_GUI_B6, GUI.TMFC_GUI_B7,...
            GUI.TMFC_GUI_B8, GUI.TMFC_GUI_B9, GUI.TMFC_GUI_B10, GUI.TMFC_GUI_B11,...
            GUI.TMFC_GUI_B12a,GUI.TMFC_GUI_B12b,GUI.TMFC_GUI_B13a,GUI.TMFC_GUI_B13b,...
            GUI.TMFC_GUI_B14a,GUI.TMFC_GUI_B14b], 'Enable', 'on');
        delete(findall(0,'type', 'Figure','Tag', 'tmfc_waitbar'));
    end
    try                                                                 
        delete(findall(0,'type','Figure','Tag', 'tmfc_waitbar'));
    end
end

end

% Save batches in parallel mode
function tmfc_parsave_batch(fname,matlabbatch)
  save(fname, 'matlabbatch')
end

% Save SPM.mat files in parallel mode
function tmfc_parsave_SPM(fname,SPM)
  save(fname, 'SPM')
end

% Waitbar for parallel mode
function tmfc_parfor_waitbar(waitbarHandle,iterations)
    persistent count h N start

    if nargin == 2
        count = 0;
        h = waitbarHandle;
        N = iterations;
        start = tic;
        
    else
        if isvalid(h)         
            count = count + 1;
            time = toc(start);
            t = seconds((N-count)*time/count); t.Format = 'hh:mm:ss';
            waitbar(count / N, h, [num2str(count/N*100,'%.f') '%, ' char(t) ' [hr:min:sec] remaining']);
        end
    end
end