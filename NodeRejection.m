function [D,varargout] = NodeRejection(B,allV,I,varargin)

% NODEREJECTION separates nodes into "signal" and "noise"
% D = NODEREJECTION(B,V,I) splits the nodes in a network into signal 
% and noise components, given: 
%       B: the modularity matrix of the network, defined using a null model (e.g Weighted Configuration Model)
%       V: the null-model eigenvalue distribution (from e.g. expectedEigsUnd) 
%       I: specified rejection interval (propotion: 0.05, for 95%; 0.01 for
%       99%, and so on); if I is specified as an n-length array {I1,I2,...,In], 
%       then a decompositin will be returned for each I  
%
% Returns: D, an n-length struct array with fields:
%               .ixSignal: the node indices in the signal component of the
%               network
%               .ixNoise: the node indices in the noise component of the
%               network
%
% ... = NODEREJECTION(...,Options) passes finds the "noise" nodes by
% weighting X:
%           'none': uses Euclidean distance of projection from the origin
%           [Default]
%           'linear': weights projections by the eigenvalues of each eigenvector
%           'sqrt': weights projections by the square root of the
%           eigenvalues of each eigenvector
%
% Notes: 
% (1) determines the number of "noise" nodes for each rejection interval;
% then finds those nodes by the shortest projections into the
% low-dimensional space of the data projections
%    
% (2) The projections can be weighted according to the eigenvalues (see
% above)
%
% ChangeLog:
% 25/7/2016: initial version
%
% Mark Humphries 25/7/2016

% sort out options
Options.Weight = 'none';

if nargin > 3
    if isstruct(Options) 
        tempopts = varargin{1}; 
        fnames = fieldnames(tempopts);
        for i = 1:length(fnames)
            Options = setfield(Options,fnames{i},getfield(tempopts,fnames{i}));
        end
    end
end

% compute eigenvalues & vectors of modularity matrix
[V,D] = eig(B);
egs = diag(D);
n = size(B,1);

% get node rejections....
D = emptyStruct({'ixSignal','ixNoise'},[numel(I) 1]);
for i = 1:numel(I)
    % find bounds, and calculate numbers to reject
    prctI = [I(i)/2*100 100-I(i)/2*100]; % rejection interval as symmetric percentile bounds
    bnds = prctile(allV,prctI); % confidence interval on eigenvalue distribution for null model

    %%%% find all eigenvalues outside of bounds
    ixpos = find(egs >= bnds(2));
    ixneg = find(egs <= bnds(1));  % use for rejection
    Tsignal = numel(ixpos) + numel(ixneg);  % total number of core nodes

    % how many to test?    
    Vpos = V(:,ixpos);      % corresponding set of eigenvectors in data-space

    %% project and reject
    switch Options.Weight
        case 'none'
            % Euclidean distance
            Vweighted = Vpos; 
        case 'linear'
            Vweighted = Vpos .* repmat(egs(ixpos)',n,1);  %weight by eigenvalues
        case 'sqrt'
            Vweighted = Vpos .* repmat((sqrt(egs(ixpos)))',n,1);
        otherwise
            error('Unknown weighting option')
    end
    
    % do projections, and divide
    lengths = sqrt(sum(Vweighted.^2,2));  % length of projection into space
    [~,I] = sort(lengths,'descend');
    D(i).ixSignal = sort(I(1:Tsignal),'ascend');  % the T retained nodes, in ID order
    D(i).ixNoise = sort(I(Tsignal+1:end),'ascend'); % removed nodes, in ID order
end


