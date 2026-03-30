clc; clear; close all;
%DENSITY_GRID_PUBLIC Grid-based density metric using synthetic building counts.
%
% This script computes a simple density-like indicator per grid cell using:
%   - pre/post point counts and diff from change_detection_grid_public.m
%   - a synthetic number of buildings per grid cell (generated here)
%
% Inputs (from ../results):
%   - change_detection_grid_synthetic_diff.csv
%       Columns: ID, Xc, Yc, Nrpre, Nrpost, diff
%
% Outputs (to ../results):
%   - density_grid_synthetic.csv
%       Columns: ID, Xc, Yc, Nrpre, Nrpost, diff, numBuildings, density
%
% Note: numBuildings is fully synthetic and only intended to demonstrate
% how a density metric could be computed; it does not reflect real counts.

%% Configuration

resultsDir = fullfile('..', 'results');
inputFile  = fullfile(resultsDir, 'change_detection_grid_synthetic_diff.csv');
outputFile = fullfile(resultsDir, 'density_grid_synthetic.csv');

makePlots = true;

%% Load grid change-detection results

data = readmatrix(inputFile);

ID    = data(:,1);
Xc    = data(:,2);
Yc    = data(:,3);
Nrpre = data(:,4);
Nrpost = data(:,5);
diff  = data(:,6);

%% Synthetic number of buildings per grid cell

% For demonstration, we create a synthetic building-count vector that is
% loosely correlated with Nrpre but does not use any real data.

rng(2026); % reproducible synthetic counts

scale = 15; % controls average number of buildings per amount of Nrpre
base  = max(1, round(Nrpre / scale));
noise = randi([-3, 3], size(base));

numBuildings = max(0, base + noise);

%% Density metric

% We focus on cells with positive pre-event points and non-negative diff.
validMask = Nrpre > 0 & diff >= 0;

% Normalise diff and synthetic building counts to [0,1] over valid cells.
diffPos = diff(validMask);
buildPos = numBuildings(validMask);

if any(diffPos > 0)
    diffNorm = (diffPos - min(diffPos)) ./ max(1, (max(diffPos) - min(diffPos)));
else
    diffNorm = zeros(size(diffPos));
end

if any(buildPos > 0)
    buildNorm = (buildPos - min(buildPos)) ./ max(1, (max(buildPos) - min(buildPos)));
else
    buildNorm = zeros(size(buildPos));
end

% Density is the product of normalised diff and normalised building count.
density = nan(size(diff));
density(validMask) = diffNorm .* buildNorm;

%% Save results

density_matrix = [ID, Xc, Yc, Nrpre, Nrpost, diff, numBuildings, density];
% Header for documentation:
% {'ID','Xc','Yc','Nrpre','Nrpost','diff','numBuildings','density'}

% Convert numeric matrix to table with headers
T = array2table(density_matrix, 'VariableNames', ...
    {'ID','Xc','Yc','Nrpre','Nrpost','diff','numBuildings','density'});

% Write to CSV
outputFile = fullfile(resultsDir, 'density_grid_synthetic.csv');  % your path
writetable(T, outputFile);

%% Optional plots

if makePlots
    % Histogram of Nrpre (non-zero)
    figure;
    histogram(Nrpre(Nrpre > 0), 50);
    xlabel('Nrpre (pre-event points per grid)');
    ylabel('Frequency');
    title('Distribution of pre-event points per grid cell');

    % Histogram of density for valid cells
    figure;
    densValid = density(validMask);
    histogram(densValid(~isnan(densValid)), 50);
    xlim([0, 1]);
    xlabel('Density');
    ylabel('Frequency');
    title('Distribution of grid-based density');

    % Scatter Nrpre vs synthetic numBuildings with trendline
    figure;
    scatter(Nrpre, numBuildings, 10, 'filled');
    xlabel('Nrpre (pre-event points per grid)');
    ylabel('Synthetic number of buildings per grid');
    hold on;
    p  = polyfit(Nrpre, numBuildings, 1);
    px = [min(Nrpre), max(Nrpre)];
    py = polyval(p, px);
    plot(px, py, 'r', 'LineWidth', 2);
    title('Relationship between Nrpre and synthetic building counts');
end

