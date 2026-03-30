clc; clear; close all;
%CHANGE_DETECTION_GRID_PUBLIC Grid-based change detection with synthetic data.
%
% This script performs change detection between pre-event and post-event
% point clouds by counting points in each grid cell. It is intended for
% public release and uses fully synthetic data.
%
% Inputs (from ../data):
%   - synthetic_grid_points.mat : contains
%       pre  [N x 3] (ID, X, Y)
%       post [M x 3] (ID, X, Y)
%       grid struct array with fields X, Y (optional, used when
%            usePredefinedGrid is true)
%
% Output (to ../results):
%   - change_detection_grid_synthetic_diff.csv
%       Columns: ID, Xc, Yc, Nrpre, Nrpost, diff
%
% The core logic (filtering by coherence, counting with inpolygon or
% histcounts2, computing differences) mirrors the original Change_detection.m.

%% Configuration

usePredefinedGrid = true;   % true: use provided grid polygons; false: auto grid
makePlot          = true;   % whether to plot grid cell centers colored by diff

dataDir    = fullfile('..', 'data');
resultsDir = fullfile('..', 'results');

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

%% Load synthetic data

DataFile = fullfile(dataDir, 'synthetic_ps.mat');
S = load(DataFile, 'pre', 'post');

gridfile = fullfile(dataDir, 'synthetic_grid_2500m.mat');
G = load(gridfile);
cells = G.gridCells;   % actual grid structure

pre  = S.pre;
post = S.post;


%% Extract coordinates (inputs already filtered)

% pre, post are [ID, X, Y]
xppre    = pre(:,2);  % X coordinates (pre)
yppre    = pre(:,3);  % Y coordinates (pre)
xppost   = post(:,2); % X coordinates (post)
yppost   = post(:,3); % Y coordinates (post)

%% Branch 1: use predefined grid polygons

if usePredefinedGrid
    if isempty(cells)
        error('No grid struct found in %s but usePredefinedGrid is true.', gridDataFile);
    end

    nCells = numel(cells);
    gridspre  = zeros(nCells, 4);
    gridspost = zeros(nCells, 4);

    for i = 1:nCells
        lon = cells(i).Lon;
        lat = cells(i).Lat;
        cellID = cells(i).ID;

        poly = polyshape(lon,lat);
        [xc,yc] = centroid(poly);

        indPre  = inpolygon(xppre,  yppre,  lon, lat);
        indPost = inpolygon(xppost, yppost, lon, lat);

        nrPre  = nnz(indPre);
        nrPost = nnz(indPost);

        gridspre(i,:)  = [cellID, xc, yc, nrPre];
        gridspost(i,:) = [cellID, xc, yc, nrPost];
    end

diff = gridspre(:,4) - gridspost(:,4);

    ID    = gridspre(:,1);
    Xc    = gridspre(:,2);
    Yc    = gridspre(:,3);
    Nrpre = gridspre(:,4);
    Nrpost = gridspost(:,4);

else
    %% Branch 2: auto-generate grid from point extents

    minx = min([min(xppre), min(xppost)]);
    maxx = max([max(xppre), max(xppost)]);
    miny = min([min(yppre), min(yppost)]);
    maxy = max([max(yppre), max(yppost)]);

    % Define grid edges (similar scale to generation script)
    cellSize = 0.002;
    edx = minx:cellSize:maxx;
    edy = miny:cellSize:maxy;

    [cxgrid, cygrid] = meshgrid( ...
        (edx(2:end) - edx(1:end-1))/2 + edx(1:end-1), ...
        (edy(2:end) - edy(1:end-1))/2 + edy(1:end-1));

    nrpre  = histcounts2(xppre,  yppre,  edx, edy).'; % Y by X
    nrpost = histcounts2(xppost, yppost, edx, edy).'; % Y by X

    diff = nrpre - nrpost;

    ID    = (1:numel(diff)).';
    Xc    = cxgrid(:);
    Yc    = cygrid(:);
    Nrpre = nrpre(:);
    Nrpost = nrpost(:);
end

%% Assemble output matrix and write CSV

diff_matrix = [ID, Xc, Yc, Nrpre, Nrpost, diff];
% Header for documentation:
% {'ID','Xc','Yc','Nrpre','Nrpost','diff'}

% Convert numeric matrix to a table with headers
T = array2table(diff_matrix, 'VariableNames', {'ID','Xc','Yc','Nrpre','Nrpost','diff'});

% Write to CSV
outFile = fullfile(resultsDir, 'change_detection_grid_synthetic_diff.csv');
writetable(T, outFile);

%% Optional visualization

if makePlot
    figure;
    scatter(Xc, Yc, 10, diff, 'filled');
    colorbar;
    xlabel('X');
    ylabel('Y');
    title('Grid-based change detection (diff = Nrpre - Nrpost)');
end

