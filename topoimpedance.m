function topoimpedance(Values, loc_file, varargin)
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

% Parse remaining optional arguments

% Check if this is an update call
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
        if Values(i) > THRESHOLD
            set(patches(i), 'FaceColor', [1 0 0]);  % red for high impedance
        else
            set(patches(i), 'FaceColor', [0 1 0]);  % green for low impedance
        end
    end
    return;
end

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
        if Values(i) > THRESHOLD
            diskcolor = [1 0 0];  % red for high impedance
        else
            diskcolor = [0 1 0];  % green for low impedance
        end
        
        % Draw filled circle with border
        patch(circle_x, circle_y, diskcolor, 'EdgeColor', HEADCOLOR, ...
              'LineWidth', DISKBORDER);
        
        % Add electrode label inside disk
        if strcmp(ELECTRODES,'labels')
            text(x(i),y(i),labels(i,:),'HorizontalAlignment','center',...
                 'VerticalAlignment','middle','Color',HEADCOLOR,...
                 'FontSize',EFSIZE);
        elseif strcmp(ELECTRODES,'numbers')
            text(x(i),y(i),int2str(i),'HorizontalAlignment','center',...
                 'VerticalAlignment','middle','Color',HEADCOLOR,...
                 'FontSize',EFSIZE);
        end
    end
end

hold off
end
