function generate_synthetic_grid_points()

rng(1234);

%% Bounding box
minX = 85.25;  maxX = 85.45;
minY = 27.65; maxY = 27.72;

%% Total number of PRE points
nPreTarget = 60000;

%% ---------------------------------------------------------
% 1️⃣ Create smooth spatial intensity surface
%% ---------------------------------------------------------

% Define main urban center
% centerX = 85.37;
% centerY = 27.69;

% Generate candidate random points (oversample)
nCandidates = 10 * nPreTarget;
xCand = minX + (maxX-minX) * rand(nCandidates,1);
yCand = minY + (maxY-minY) * rand(nCandidates,1);


%% -------------------------------------------------
% Create irregular smooth intensity field
%% -------------------------------------------------

nx = 200; ny = 200;
[Xg,Yg] = meshgrid(linspace(minX,maxX,nx), ...
                   linspace(minY,maxY,ny));

Z = randn(ny,nx);
Z = imgaussfilt(Z, 15);   % smooth it
Z = Z - min(Z(:));
Z = Z / max(Z(:));

% Interpolate intensity at candidate points
intensity = interp2(Xg, Yg, Z, xCand, yCand);
intensity = intensity + 0.15;   % ensure coverage everywhere
intensity = intensity / max(intensity);
intensity = intensity / max(intensity); % normalize to probability

% Accept-reject sampling
keep = rand(nCandidates,1) < intensity;
xPre = xCand(keep);
yPre = yCand(keep);

% Trim to desired count
if length(xPre) > nPreTarget
    idx = randperm(length(xPre), nPreTarget);
    xPre = xPre(idx);
    yPre = yPre(idx);
end

nPre = length(xPre);
pre  = [(1:nPre)', xPre, yPre];

%% ---------------------------------------------------------
% 2️⃣ Generate POST distribution (spatially correlated reduction)
%% ---------------------------------------------------------

postRatio = 0.18;  % similar to your real data

damageField = 0.4 + 0.6 * (xPre - minX) / (maxX - minX); % more loss east side
survivalProb = postRatio * (1 - 0.5 * damageField);

keepPost = rand(nPre,1) < survivalProb;
post = pre(keepPost,:);

%% ---------------------------------------------------------
% Save PRE and POST points
%% ---------------------------------------------------------

save('synthetic_ps.mat','pre','post','-v7.3');
fprintf('Pre points : %d\n', size(pre,1));
fprintf('Post points: %d\n', size(post,1));

%% ---------------------------------------------------------
% 3️⃣ Generate 100m x 100m grid
%% ---------------------------------------------------------

meanLat = (minY + maxY)/2;
m_per_deg_lat = 111000;                     % meters per degree latitude
m_per_deg_lon = 111000 * cosd(meanLat);     % meters per degree longitude

dx = 2500 / m_per_deg_lon;   % 2500m in degrees longitude
dy = 2500 / m_per_deg_lat;   % 2500m in degrees latitude

xGrid = minX:dx:maxX;
if xGrid(end) < maxX
    xGrid = [xGrid maxX];
end

yGrid = minY:dy:maxY;
if yGrid(end) < maxY
    yGrid = [yGrid maxY];
end

gridCells = [];
cellId = 1;
for i = 1:length(xGrid)-1
    for j = 1:length(yGrid)-1
        gridCells(cellId).Lon = [xGrid(i) xGrid(i+1) xGrid(i+1) xGrid(i) xGrid(i)];
        gridCells(cellId).Lat = [yGrid(j) yGrid(j) yGrid(j+1) yGrid(j+1) yGrid(j)];
        gridCells(cellId).ID = cellId;
        cellId = cellId + 1;
    end
end

% Save grid
save('synthetic_grid_2500m.mat','gridCells','-v7.3');
fprintf('Generated %d grid cells and saved to synthetic_grid_2500m.mat\n', length(gridCells));

%% ---------------------------------------------------------
% 4️⃣ Visualization with grid overlay
%% ---------------------------------------------------------

figure;

% Pre-event plot
subplot(1,2,1)
scatter(pre(:,2), pre(:,3), 8, '.b')
axis equal
xlim([minX maxX]); ylim([minY maxY])
title('Pre-event PS distribution')
xlabel('Longitude'); ylabel('Latitude')
hold on
for k = 1:length(gridCells)
    plot(gridCells(k).Lon, gridCells(k).Lat, 'k-', 'LineWidth', 0.5);
end
hold off

% Post-event plot
subplot(1,2,2)
scatter(post(:,2), post(:,3), 8, '.r')
axis equal
xlim([minX maxX]); ylim([minY maxY])
title('Post-event PS distribution')
xlabel('Longitude'); ylabel('Latitude')
hold on
for k = 1:length(gridCells)
    plot(gridCells(k).Lon, gridCells(k).Lat, 'k-', 'LineWidth', 0.5);
end
hold off

end