function fig = topoimpedance(Values, loc_file, varargin)
% topoimpedance() - plot electrode locations with impedance circles
% Usage:
%        >>  topoimpedance(impedance_values, EEG.chanlocs);
%        >>  topoimpedance(impedance_values, EEG.chanlocs, 'update', figure_handle);
% Inputs:
%   Values        - vector of impedance values for each electrode
%   loc_file      - EEG.chanlocs structure or location file
% Optional inputs:
%   'electrodes'  - 'on'|'off'|'labels'|'numbers' {default: 'on'}
%   'headrad'     - [0.15<=float<=1.0] head radius {default: 0.5}
%   'plotrad'     - [0.15<=float<=1.0] plotting radius {default: 0.5}
%   'nosedir'     - ['+X'|'-X'|'+Y'|'-Y'] direction of nose {default: '+X'}
%   'verbose'     - ['on'|'off'] {default: 'off'}
%   'update'      - figure handle for updating existing plot

% Set defaults
ELECTRODES = 'on';
HEADCOLOR = [0 0 0];
rmax = 0.5;             % actual head radius
headrad = 0.5;          % head radius
CIRCGRID = 201;         % number of angles to use in drawing circles
AXHEADFAC = 1.3;        % head to axes scaling factor
HLINEWIDTH = 2;         % default linewidth for head, nose, ears
DISKSIZE = 0.04;        % constant size for impedance disks
DISKBORDER = 1;         % border width for disks
THRESHOLD = 0.5;        % threshold for red/green coloring
EFSIZE = get(0,'DefaultAxesFontSize'); % use current default fontsize for electrode labels
figHandle = [];

% UI parameters
persistent UI_PARAMS;
if isempty(UI_PARAMS)
    UI_PARAMS = struct();
    UI_PARAMS.threshold = 0.5;
    UI_PARAMS.freq_center = 32.1;  % Hz
    UI_PARAMS.freq_spread = 1;   % Hz
    UI_PARAMS.current = 6;       % nA
    UI_PARAMS.show_labels = true;
    UI_PARAMS.show_values = false;
end

% Parse remaining optional arguments
if ~isempty(varargin)
    for i = 1:2:length(varargin)
        Param = varargin{i};
        Value = varargin{i+1};
        if ~ischar(Param)
            error('Flag arguments must be strings')
        end
        Param = lower(Param);
        switch Param
            case 'electrodes'
                ELECTRODES = lower(Value);
            case 'headrad'
                headrad = Value;
            case 'update'
                figHandle = Value;
        end
    end
end

% If this is an update call, just update the disk colors
if ~isempty(figHandle)
    if ~ishandle(figHandle)
        error('Invalid figure handle provided for update');
    end
    figure(figHandle);
    ax = gca;
    patches = findobj(ax, 'Type', 'patch');
    
    % Update colors based on new values
    for i = 1:length(patches)
        if Values(i) > UI_PARAMS.threshold
            set(patches(i), 'FaceColor', [1 0 0]);  % red for high impedance
        else
            set(patches(i), 'FaceColor', [0 1 0]);  % green for low impedance
        end
    end
    
    % Update text visibility
    text_objects = findobj(ax, 'Type', 'text');
    for i = 1:length(text_objects)
        if ~isempty(text_objects(i).UserData)
            % check if values are visible and update them
            if strcmp(text_objects(i).UserData, 'value')
                text_objects(i).Visible = UI_PARAMS.show_values;
                text_objects(i).String = sprintf('%.1f', Values((i+1)/2));
            end
        end
    end
    return;
end

% Create figure with UI panel
fig = figure('Position', [100 100 900 600], 'MenuBar', 'none', 'ToolBar', 'none', 'Name', 'Impedance', 'NumberTitle', 'off');
set(fig, 'Color', [0.94 0.94 0.94]);

% Create UI panel
panel = uipanel('Title', 'Parameters', 'Position', [0.02 0.02 0.20 0.96]);

% Threshold slider
uicontrol('Parent', panel, 'Style', 'text', 'String', 'Threshold:', ...
    'Position', [10 530 150 20]);
uicontrol('Parent', panel, 'Style', 'slider', ...
    'Position', [10 510 150 20], ...
    'Min', 0, 'Max', 1, 'Value', UI_PARAMS.threshold, ...
    'Callback', @updateThreshold);
threshold_text = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', sprintf('%.2f', UI_PARAMS.threshold), ...
    'Position', [10 490 150 20], ...
    'Callback', @updateThresholdFromText);

% Frequency center
uicontrol('Parent', panel, 'Style', 'text', 'String', 'Freq Center (Hz):', ...
    'Position', [10 450 150 20]);
uicontrol('Parent', panel, 'Style', 'edit', ...
    'Position', [10 430 150 20], ...
    'String', num2str(UI_PARAMS.freq_center), ...
    'Callback', @updateFreqCenter);

% Frequency spread
uicontrol('Parent', panel, 'Style', 'text', 'String', 'Freq Spread (Hz):', ...
    'Position', [10 400 150 20]);
uicontrol('Parent', panel, 'Style', 'edit', ...
    'Position', [10 380 150 20], ...
    'String', num2str(UI_PARAMS.freq_spread), ...
    'Callback', @updateFreqSpread);

% Current
uicontrol('Parent', panel, 'Style', 'text', 'String', 'Current (nA):', ...
    'Position', [10 350 150 20]);
uicontrol('Parent', panel, 'Style', 'edit', ...
    'Position', [10 330 150 20], ...
    'String', num2str(UI_PARAMS.current), ...
    'Callback', @updateCurrent);

% Show labels checkbox
uicontrol('Parent', panel, 'Style', 'checkbox', ...
    'Position', [10 300 150 20], ...
    'String', 'Show Labels', ...
    'Value', UI_PARAMS.show_labels, ...
    'Callback', @toggleLabels);

% Show values checkbox
uicontrol('Parent', panel, 'Style', 'checkbox', ...
    'Position', [10 270 150 20], ...
    'String', 'Show Values', ...
    'Value', UI_PARAMS.show_values, ...
    'Callback', @toggleValues);

% Create axes for the plot
ax = axes('Position', [0.3 0.1 0.65 0.8]);

% Read channel locations
if ischar(loc_file) || isstruct(loc_file)
    [~, labels, Th, Rd] = readlocs(loc_file);
else
    error('loc_file must be a EEG.locs struct or locs filename');
end

% Convert to radians and get coordinates
Th = pi/180*Th;
[x,y] = pol2cart(Th,Rd);

% Apply default -90 degree rotation to match topoplot.m
allcoords = (y + x*sqrt(-1))*exp(-sqrt(-1)*pi/2);
x = imag(allcoords);
y = real(allcoords);

% Set up the plot
axes(ax);
cla
hold on
% Add DISKSIZE to the limits to show full disks
set(gca,'Xlim',[-rmax-DISKSIZE rmax+DISKSIZE]*AXHEADFAC,'Ylim',[-rmax-DISKSIZE rmax+DISKSIZE]*AXHEADFAC);
axis square
axis off

% Draw head outline
circ = linspace(0,2*pi,CIRCGRID);
rx = sin(circ); 
ry = cos(circ); 
headx = [rx(:)' rx(1)]*headrad;
heady = [ry(:)' ry(1)]*headrad;
plot(headx,heady,'color',HEADCOLOR,'linewidth',HLINEWIDTH);

% Draw nose
base = rmax-.0046;
basex = 0.18*rmax;
tip = 1.15*rmax;
tiphw = .04*rmax;
tipr = .01*rmax;
plot([basex;tiphw;0;-tiphw;-basex],[base;tip-tipr;tip;tip-tipr;base],...
     'Color',HEADCOLOR,'LineWidth',HLINEWIDTH);

% Draw ears
q = .04;
EarX = [.497-.005  .510  .518  .5299 .5419  .54    .547   .532   .510   .489-.005];
EarY = [q+.0555 q+.0775 q+.0783 q+.0746 q+.0555 -.0055 -.0932 -.1313 -.1384 -.1199];
plot(EarX,EarY,'color',HEADCOLOR,'LineWidth',HLINEWIDTH);
plot(-EarX,EarY,'color',HEADCOLOR,'LineWidth',HLINEWIDTH);

% Plot impedance circles
if ~isempty(Values)
    for i = 1:length(x)
        % Draw circle with constant size
        circ = linspace(0,2*pi,32);
        circle_x = x(i) + DISKSIZE*cos(circ);
        circle_y = y(i) + DISKSIZE*sin(circ);
        
        % Choose color based on threshold
        if Values(i) > UI_PARAMS.threshold
            diskcolor = [1 0 0];  % red for high impedance
        else
            diskcolor = [0 1 0];  % green for low impedance
        end
        
        % Draw filled circle with border
        patch(circle_x, circle_y, diskcolor, 'EdgeColor', HEADCOLOR, ...
              'LineWidth', DISKBORDER);
        
        % Add electrode label
        h = text(x(i),y(i),labels{i},'HorizontalAlignment','center',...
             'VerticalAlignment','middle','Color',HEADCOLOR,...
             'FontSize',EFSIZE);
        set(h, 'UserData', 'label');
        set(h, 'Visible', UI_PARAMS.show_labels);
        
        % Add impedance value
        value_str = sprintf('%.1f', Values(i));
        h = text(x(i),y(i),value_str,...
             'HorizontalAlignment','center',...
             'VerticalAlignment','middle','Color',HEADCOLOR,...
             'FontSize',EFSIZE);
        set(h, 'UserData', 'value');
        set(h, 'Visible', UI_PARAMS.show_values);
    end
end

hold off

% Callback functions
function updateThreshold(source, ~)
    UI_PARAMS.threshold = source.Value;
    % Update threshold text display
    threshold_text = findobj(source.Parent, 'Style', 'edit', 'Position', [10 490 150 20]);
    set(threshold_text, 'String', sprintf('%.2f', UI_PARAMS.threshold));
    
    % Update colors
    patches = findobj(ax, 'Type', 'patch');
    for i = 1:length(patches)
        if Values(i) > UI_PARAMS.threshold
            set(patches(i), 'FaceColor', [1 0 0]);
        else
            set(patches(i), 'FaceColor', [0 1 0]);
        end
    end
end

function updateThresholdFromText(source, ~)
    % Get the new value from the text field
    new_value = str2double(source.String);
    
    % Validate the input
    if isnan(new_value) || new_value < 0 || new_value > 1
        % If invalid, revert to previous value
        set(source, 'String', sprintf('%.2f', UI_PARAMS.threshold));
        return;
    end
    
    % Update the threshold value
    UI_PARAMS.threshold = new_value;
    
    % Update the slider
    slider = findobj(source.Parent, 'Style', 'slider', 'Position', [10 510 150 20]);
    set(slider, 'Value', new_value);
    
    % Update colors
    patches = findobj(ax, 'Type', 'patch');
    for i = 1:length(patches)
        if Values(i) > UI_PARAMS.threshold
            set(patches(i), 'FaceColor', [1 0 0]);
        else
            set(patches(i), 'FaceColor', [0 1 0]);
        end
    end
end

function updateFreqCenter(source, ~)
    UI_PARAMS.freq_center = str2double(source.String);
    % Add your frequency update logic here
end

function updateFreqSpread(source, ~)
    UI_PARAMS.freq_spread = str2double(source.String);
    % Add your frequency spread update logic here
end

function updateCurrent(source, ~)
    UI_PARAMS.current = str2double(source.String);
    % Add your current update logic here
end

function toggleLabels(source, ~)
    UI_PARAMS.show_labels = source.Value;
    if UI_PARAMS.show_labels
        % Uncheck values checkbox
        values_checkbox = findobj(source.Parent, 'Style', 'checkbox', 'String', 'Show Values');
        set(values_checkbox, 'Value', 0);
        UI_PARAMS.show_values = false;
    end
    
    % Update labels visibility
    text_objects = findobj(ax, 'Type', 'text');
    for i = 1:length(text_objects)
        if ~isempty(text_objects(i).UserData)
            if strcmp(text_objects(i).UserData, 'label')
                text_objects(i).Visible = UI_PARAMS.show_labels;
            elseif strcmp(text_objects(i).UserData, 'value')
                text_objects(i).Visible = UI_PARAMS.show_values;
            end
        end
    end
end

function toggleValues(source, ~)
    UI_PARAMS.show_values = source.Value;
    if UI_PARAMS.show_values
        % Uncheck labels checkbox
        labels_checkbox = findobj(source.Parent, 'Style', 'checkbox', 'String', 'Show Labels');
        set(labels_checkbox, 'Value', 0);
        UI_PARAMS.show_labels = false;
    end
    
    % Update values visibility
    text_objects = findobj(ax, 'Type', 'text');
    for i = 1:length(text_objects)
        if ~isempty(text_objects(i).UserData)
            if strcmp(text_objects(i).UserData, 'label')
                text_objects(i).Visible = UI_PARAMS.show_labels;
            elseif strcmp(text_objects(i).UserData, 'value')
                text_objects(i).Visible = UI_PARAMS.show_values;
            end
        end
    end
end

end
