clc; clear; close all;
%CHANGE_DETECTION_BUILDING_PUBLIC Building-based change detection with synthetic data.
%
% This script performs change detection between pre-event and post-event
% point clouds by counting points inside each building footprint polygon.
% It is intended for public release and uses fully synthetic data.
%
% Inputs (from ../data):
%   - synthetic_ps.mat : pre, post [N x 3] (ID, X, Y)
%   - buildings_2.mat : buildings (struct array X, Y, osm_id) — spatial subset
%       of Kathmandu OSM footprints for public release (same schema as full data).
%
% Output (to ../results):
%   - change_detection_buildings_synthetic_diff.csv
%       Columns: ID, Xc, Yc, Nrpre, Nrpost, diff
%
% The core logic (filtering by coherence, inpolygon counting, centroid
% computation) mirrors the original Change_detection_building.m.

%% Configuration

makePlot   = true;   % whether to plot building centroids colored by diff_1

dataDir    = fullfile('..', 'data');
resultsDir = fullfile('..', 'results');

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

%% Load synthetic data

gridDataFile = fullfile(dataDir, 'synthetic_ps.mat');
buildingsFile = fullfile(dataDir, 'buildings_2.mat');

Gs = load(gridDataFile, 'pre', 'post');
Bs = load(buildingsFile, 'buildings');

pre     = Gs.pre;
post    = Gs.post;
buildings = Bs.buildings;

%% Extract coordinates (inputs already filtered)

% pre, post are [ID, X, Y]
xppre  = pre(:,2);  % X coordinates (pre)
yppre  = pre(:,3);  % Y coordinates (pre)
xppost = post(:,2); % X coordinates (post)
yppost = post(:,3); % Y coordinates (post)

%% Count points per building

nBuildings = numel(buildings);
bu_pre  = zeros(nBuildings, 4);
bu_post = zeros(nBuildings, 4);

for i = 1:nBuildings
    osm_id = buildings(i).osm_id;

    polygons = {buildings(i).X, buildings(i).Y};

    poly = polyshape({buildings(i).X}, {buildings(i).Y});
    [xc, yc] = centroid(poly); % centroid of each building

    indpre = inpolygon(xppre,  yppre,  polygons{:,1}, polygons{:,2});
    indPost   = inpolygon(xppost, yppost, polygons{:,1}, polygons{:,2});

    countspre  = numel(xppre(indpre));
    countspost = numel(xppost(indPost));

    bu_pre(i,1)  = str2double(osm_id);
    bu_pre(i,2)  = xc;
    bu_pre(i,3)  = yc;
    bu_pre(i,4)  = countspre;

    bu_post(i,1) = str2double(osm_id);
    bu_post(i,2) = xc;
    bu_post(i,3) = yc;
    bu_post(i,4) = countspost;
end

%% Difference and output

diff = bu_pre(:,4) - bu_post(:,4);

ID    = bu_pre(:,1);
Xc    = bu_pre(:,2);
Yc    = bu_pre(:,3);
Nrpre = bu_pre(:,4);
Nrpost = bu_post(:,4);

diff_matrix = [ID, Xc, Yc, Nrpre, Nrpost, diff];
% Header for documentation:
% {'ID','Xc','Yc','Nrpre','Nrpost','diff'}

T = array2table(diff_matrix, 'VariableNames', {'ID','Xc','Yc','Nrpre','Nrpost','diff'});
outFile = fullfile(resultsDir, 'change_detection_buildings_synthetic_diff.csv');
writetable(T, outFile);

%% Optional quick plot

if makePlot
    figure;
    scatter(Xc, Yc, 10, diff, 'filled');
    colorbar;
    xlabel('X');
    ylabel('Y');
    title('Building-based change detection (diff = Nrpre - Nrpost)');
end

