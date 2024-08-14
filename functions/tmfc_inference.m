function [thres_1, p_val] = tmfc_inference(matrix_add,contrast,alpha,perm, pval,test_type)


% IF LENGTH (MATRIX) > 1

if length(matrix_add) > 1
% LOAD MATRICES INDIVIDUALLY 
    disp('load individual matrices');
else
    
    matrix = importdata(matrix_add{:});
%(i.e. MATRICES ARE 1 i.e. M x N x O    

end




%fprintf('contrast = %d, Alpha = %d, test_type = %s', contrast, alpha, test_type);


switch (test_type)
    
    case 'Uncorrected (Parametric)'
         
        % perm, p_val
        N = length(matrix);

        % multiply contrasts 


        for i=1:N
            for j = 1:N
                [h,p(i,j)] = ttest(matrix(i,j,:));        
            end
        end

        thres_1 = [];
        thres_1 = p<alpha;
        figure;
        imagesc(thres_1);
        
        %disp('Uncorr para');
        %fprintf('contrast = %d, Alpha = %d', contrast, alpha);
        
    case 'FDR (Parametric)'
        
        disp('FDR para');
        fprintf('contrast = %d, Alpha = %d', contrast, alpha);
    
                % perm, p_val
        N = length(matrix);

        % multiply contrasts 


        for i=1:N
            for j = 1:N
                [h,p(i,j)] = ttest(matrix(i,j,:));        
            end
        end

        thres_1 = [];
        
        p2 = p(isfinite(p));  % Toss NaN's
        p2 = sort(p(:));
        V = length(p);
        I = (1:V)';

        cVID = 1;
        cVN = sum(1./(1:V));
        q = alpha;
        pID = p(max(find(p<=I/V*q/cVID)));
        if isempty(pID), pID=0; end
        pN = p(max(find(p<=I/V*q/cVN)));
        if isempty(pN), pN=0; end
        
        thres_1 = p<pID;
        figure;
        imagesc(thres_1);
        
    case 'Uncorrected (Non-Parametric)'
        disp('working Uncorr, non para');
        fprintf('contrast = %d, Alpha = %d', contrast, alpha);
        
    case 'FDR (Non-Parametric)'
        disp('FDR non para');
        fprintf('contrast = %d, Alpha = %d', contrast, alpha);
        
    case 'NBS FWE(Non-Parametric)'
        disp('NBS FEW non para');
        fprintf('contrast = %d, Alpha = %d', contrast, alpha);
        
    case 'NBS TFCE(Non-Parametric)'
        disp('TFCE non para');
        fprintf('contrast = %d, Alpha = %d', contrast, alpha);
end



end