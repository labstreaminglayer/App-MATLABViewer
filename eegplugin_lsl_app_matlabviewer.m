% eegplugin_lsl_app_matlabviewer() - EEGLAB plugin for Matlab LSL viewer.
% 
% Usage:
%   >> eegplugin_lsl_app_matlabviewer(fig, trystrs, catchstrs);
%
% Inputs:
%   fig        - [integer]  EEGLAB figure
%   trystrs    - [struct] "try" strings for menu callbacks.
%   catchstrs  - [struct] "catch" strings for menu callbacks.
%
% Authors: Arnaud Delorme for the plugin and Christian Kothe for the viewer
%
% See also: pop_loadbv()

% Copyright (C) 2004 Arnaud Delorme
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function vers = eegplugin_lsl_app_matlabviewer(fig, trystrs, catchstrs)

    vers = 'lsl_app_matlabviewer1.2';
    if nargin < 3
        error('eegplugin_bva_io requires 3 arguments');
    end
    
    % add folder to path
    % ------------------
    if ~exist('eegplugin_lsl_app_matlabviewer')
        p = which('eegplugin_lsl_app_matlabviewer.m');
        p = p(1:findstr(p,'eegplugin_lsl_app_matlabviewer.m')-1);
        addpath( p );
        addpath( fullfile(p, 'liblsl-Matlab') );
        addpath( fullfile(p, 'liblsl-Matlab', 'bin') );
        addpath( fullfile(p, 'liblsl-Matlab', 'mex') );
        addpath( fullfile(p, 'arg_system') );
    end
    
    % find import data menu
    % ---------------------
    menui = findobj(fig, 'label', 'File');
    
    % menu callbacks
    % --------------
    comcnt1 = 'vis_stream;';
                
    % create menus
    % ------------
    uimenu( menui, 'label', 'Matlab LSL viewer',  'callback', comcnt1, 'separator', 'on', 'position', 5 );
