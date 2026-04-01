clc; clear; close all;
%DENSITY_BUILDING_PUBLIC Building-based density metric using building areas.
%
% This script computes a simple density-like indicator per building using:
%   - pre/post point counts and diff from change_detection_building_public.m
%   - the footprint area of each building from buildings_2.mat (subset; see README)
%
% Inputs:
%   - ../results/change_detection_buildings_synthetic_diff.csv
%       Columns: ID, Xc, Yc, Nrpre, Nrpost, diff
%   - ../data/buildings_2.mat
%       Variable: buildings (struct with fields X, Y, osm_id)
%
% Outputs:
%   - ../results/density_buildings_synthetic.csv
%       Columns: ID, Xc, Yc, Nrpre, Nrpost, diff, area, density

%% Configuration

dataDir    = fullfile('..', 'data');
resultsDir = fullfile('..', 'results');

inputFileChange = fullfile(resultsDir, 'change_detection_buildings_synthetic_diff.csv');
inputFileBuildings = fullfile(dataDir, 'buildings_2.mat');
outputFile = fullfile(resultsDir, 'density_buildings_synthetic.csv');

makePlots = true;

%% Load change detection results and buildings

change_bu = readmatrix(inputFileChange);

ID      = change_bu(:,1);
Xc      = change_bu(:,2);
Yc      = change_bu(:,3);
Nrpre   = change_bu(:,4);
Nrpost  = change_bu(:,5);
diff    = change_bu(:,6);

B = load(inputFileBuildings, 'buildings');
buildings = B.buildings;

%% Compute building areas from footprints

nBuildings = numel(buildings);
areaVals   = zeros(nBuildings, 1);
idFromShapes = zeros(nBuildings,1);

for i = 1:nBuildings
    poly = polyshape(buildings(i).X, buildings(i).Y);
    areaVals(i) = area(poly);
    idFromShapes(i) = str2double(buildings(i).osm_id);
end

%% Align areas with change_bu rows using ID

area = nan(size(ID));

for i = 1:numel(ID)
    idx = find(idFromShapes == ID(i), 1, 'first');
    if ~isempty(idx)
        area(i) = areaVals(idx);
    end
end

%% Density metric

% Focus on buildings with non-zero Nrpre and non-negative diff and area.
validMask = Nrpre > 0 & diff >= 0 & area > 0;

diffPos  = diff(validMask);
areaPos  = area(validMask);

% Normalise diff and area to [0,1] for valid buildings.
if any(diffPos > 0)
    diffNorm = (diffPos - min(diffPos)) ./ max(1, (max(diffPos) - min(diffPos)));
else
    diffNorm = zeros(size(diffPos));
end

if any(areaPos > 0)
    areaNorm = (areaPos - min(areaPos)) ./ max(1, (max(areaPos) - min(areaPos)));
else
    areaNorm = zeros(size(areaPos));
end

% Density is the product of normalised diff and normalised area.
density = nan(size(diff));
density(validMask) = diffNorm .* areaNorm;

%% Save results

density_matrix = [ID, Xc, Yc, Nrpre, Nrpost, diff, area, density];
% Header for documentation:
% {'ID','Xc','Yc','Nrpre','Nrpost','diff','area','density'}

T = array2table(density_matrix, 'VariableNames', ...
    {'ID','Xc','Yc','Nrpre','Nrpost','diff','numBuildings','density'});

% Write to CSV
outputFile = fullfile(resultsDir, 'density_building_synthetic.csv');  % your path
writetable(T, outputFile);

%% Optional plots

if makePlots
    % Histogram of building areas
    figure;
    histogram(area(area > 0), 100);
    xlabel('Building area');
    ylabel('Frequency');
    title('Distribution of building areas');

    % Histogram of density for valid buildings
    figure;
    densValid = density(validMask);
    histogram(densValid(~isnan(densValid)), 50);
    % xlim([0, 1]);
    xlabel('Density');
    ylabel('Frequency');
    title('Distribution of building-based density');
end

