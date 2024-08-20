function [thresholded,pval,tval,conval] = tmfc_ttest(matrices,contrast,alpha,correction)

% ========= Task-Modulated Functional Connectivity (TMFC) toolbox =========
%
% Performes one-sanple t-test for symmetrical connectivity matrices.
%
% FORMAT [thresholded,pval,tval,conval] = tmfc_ttest(matrices,contrast,alpha,correction)
%
% INPUTS:
%
% matrices    - connectivity matrices (ROI x ROI x Subjects)
% contrast    - contrast weight
% alpha       - alpha level
% correction  - correction for multiple comparisons:
%               'uncorr' - uncorrected
%               'FDR'    - False Discovery Rate correction (BH procedure)
%               'Bonf'   - Bonferroni correction
%
% OUTPUTS:
%
% thresholded - thresholded binary matrix 
%               (1 - significant connection, 0 - n.s.)
% pval        - uncorrected p-value matrix
% tval        - t-value matrix
% conval      - group mean contrast value 
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


N_ROI = size(matrices,1);
matrices = contrast.*matrices;
conval = mean(matrices,3);

for roii = 1:N_ROI
    for roij = roii+1:N_ROI
        [~,pval(roii,roij),~,stat] = ttest(shiftdim(matrices(roii,roij,:)));
        tval(roii,roij) = stat.tstat;
        pval(roij,roii) = pval(roii,roij);
        tval(roij,roii) = tval(roii,roij);
    end
end

matrix_mask = ones(N_ROI,N_ROI);
matrix_mask = tril(matrix_mask,-1);
a_mask = matrix_mask(:);

for i = 1:size(matrices,3)
    tmp = matrices(:,:,i);
    a_matrix = tmp(:);
    a_matix_masked(i,:) = a_matrix(find(a_mask)); 
end

switch correction
    case 'uncorr'
        thresholded = double(pval<alpha);
        thresholded(1:1+N_ROI:end) = 0;

    case 'FDR'
        [~,p] = ttest(a_matix_masked);
        [alpha_FDR] = FDR(p,alpha);
        thresholded = double(pval<alpha_FDR);
        thresholded(1:1+N_ROI:end) = 0;

    case 'Bonf'
        alpha_Bonf = alpha/(N_ROI*(N_ROI-1)/2);
        thresholded = double(pval<alpha_Bonf);
        thresholded(1:1+N_ROI:end) = 0;

    otherwise
    thresholded = [];
    pval = [];
    tval = [];
    conval = [];
    warning('Work in progress. Please wait for future updates');

end
end

function low = lower_triangle(matrix)

matrix(1:1+N_ROI:end) = NaN;
low = matrix(tril(true(size(matrix)))).';
low(isnan(low)) = [];

end

function [pID] = FDR(p,q)

p = p(isfinite(p));
p = sort(p(:));
V = length(p);
I = (1:V)';
cVID = 1;

pID = p(max(find(p<=I/V*q/cVID)));
if isempty(pID), pID=0; end

end