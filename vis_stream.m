function vis_stream(varargin)
% Display an LSL stream.
%
% Keyboard shortcuts:
%   [up arrow]   : increase the y scale of the time series
%   [down arrow] : decrease the y scale of the time series
%   [right arrow]: increase the displayed time range
%   [left arrow] : decrease the displayed time range
%   [page up]    : go up by one page of channels
%   [page down]  : go down by one page of channels
%
% In:
%   StreamName : Stream to display. The name of the stream that you would like to display.
%
%   Display options:
%
%       TimeScale : Initial time scale in seconds. The time range of the display window;
%                   can be changed with keyboard shortcuts (see help). Default=5
% 
%       DataScale : Initial scale of the data. The scale of the data, in units between horizontal lines;
%                   can be changed with keyboard shortcuts (see help). Default=150
% 
%       ChannelRange : Channels to display. The channel range to display. Default=[1:32]
% 
%       SamplingRate : Sampling rate for display. This is the sampling rate that is used for plotting, in Hz;
%                      for faster drawing. Default=100
% 
%       RefreshRate : Refresh rate for display. This is the rate at which the graphics are updated, in Hz.
%                     Default=10
%
%   Processing Options:
%
%       FrequencyFilter : Frequency filter. The parameters of a bandpass filter
%                         [raise-start,raise-stop,fall-start,fall-stop], e.g., [7 8 14 15] for a filter
%                         with 8-14 Hz pass-band and 1 Hz transition bandwidth between passband and
%                         stop-bands; if given as a single scalar, a moving-average filter is designed
%                         (legacy option). Default=0
% 
%       Rereference : Apply common-average re-referencing to the data. Useful for noisy EEG streams.
%                     Default=false
% 
%       Standardize: Standardize the data. Default=false
% 
%       ZeroMean: Zero-mean the data. Default=true
%
%   Misc Options:
%
%       ParentFigure : Parent figure, if any
% 
%       ParentAxes : Axes to render into, if any
% 
%       PageOffset : Channel page offset. Allows to flip forward or backward pagewise through the displayed channels.
%                    Default=0
% 
%       Position : Figure position. Allows to script the position at which the figures should appear.
%                  This is a 4-element vector of the form [X-offset,Y-offset,Width,Height]
%                  with all values in pixes.
%                  Default=[]
%
%                                Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
%                                2012-07-10
%
%                                uses portions of vis_dataStreamViewer
%                                (c) 2012 by Tim Mullen


% make sure that dependencies are on the path and that LSL is loaded
evalin('base', 'global EEG;');
if ~isdeployed
    if ~exist('lsl_loadlib','file')
        addpath(genpath(fileparts(mfilename('fullpath')))); 
    end
    try
        p = path;
        if ~isempty(strfind(p, 'Contents/MacOS'))
            error('Path corrupted, remove compiled folder');
        end
    catch
        error('Path corrupted, remove compiled folder');
    end        
end
try
    lib = lsl_loadlib(env_translatepath('dependencies:/liblsl-Matlab/bin'));
catch
    lib = lsl_loadlib();
end

% handle input arguments
streamnames = find_streams(lib);

if isempty(streamnames)
    if isempty(varargin)
        errordlg('There is no stream visible on the network.'); 
        return
    else
        error('There is no stream visible on the network.'); 
    end
end

    % arg({'notchfilter','NotchFilter'},0,[0 Inf],'Notch filter. Enter 50 or 60 based on line noise frequency in your country.'), ...
opts = arg_define(varargin, ...
    arg({'streamname','StreamName'},streamnames{1},streamnames,'LSL stream that should be displayed. The name of the stream that you would like to display.'), ...
    arg({'bufferrange','BufferRange'},10,[0 Inf],'Maximum time range to buffer. Imposes an upper limit on what can be displayed.'), ...
    arg({'timerange','TimeRange'},5,[0 Inf],'Initial time range in seconds. The time range of the display window; can be changed with keyboard shortcuts (see help).'), ...
    arg({'rmsrange','RMSRange'},1,[0 Inf],'RMS time range in seconds.'), ...
    arg({'datascale','DataScale'},150,[0 Inf],'Initial scale of the data. The scale of the data, in units between horizontal lines; can be changed with keyboard shortcuts (see help).'), ...
    arg({'channelrange','ChannelRange'},1:32,uint32([1 1000000]),'Channels to display. The channel range to display.'), ...
    arg({'samplingrate','SamplingRate'},100,[0 Inf],'Sampling rate for display. This is the sampling rate that is used for plotting; for faster drawing.'), ...
    arg({'refreshrate','RefreshRate'},10,[0 Inf],'Refresh rate for display. This is the rate at which the graphics are updated.'), ...
    arg({'freqfilter','FrequencyFilter','moving_avg','MovingAverageLength'},0,[0 Inf],'Frequency filter. The parameters of a bandpass filter [raise-start,raise-stop,fall-start,fall-stop], e.g., [7 8 14 15] for a filter with 8-14 Hz pass-band and 1 Hz transition bandwidth between passband and stop-bands; if given as a single scalar, a moving-average filter is designed (legacy option).'), ...
    arg({'reref','Rereference'},false,[],'Common average reference. Enable this to view the data with a common average reference filter applied.'), ...
    arg({'standardize','Standardize'},false,[],'Standardize data.'), ...
    arg({'rms','RMS'},true,[],'Show RMS for each channel.'), ...
    arg({'zeromean','ZeroMean'},true,[],'Zero-mean data.'), ...
    arg({'recordbut','RecordButton'},true,[],'Show Record button.'), ...
    arg_nogui({'parent_fig','ParentFigure'},[],[],'Parent figure handle.'), ...
    arg_nogui({'parent_ax','ParentAxes'},[],[],'Parent axis handle.'), ...    
    arg_nogui({'pageoffset','PageOffset'},0,uint32([0 100]),'Channel page offset. Allows to flip forward or backward pagewise through the displayed channels.'), ...
    arg_nogui({'position','Position'},[],[],'Figure position. Allows to script the position at which the figures should appear.','shape','row'));

if ~isempty(varargin)
    % create stream inlet, figure and stream buffer
    inlet = create_inlet(lib,opts);
    stream = create_streambuffer(opts,inlet.info()); 
    
    [fig,axrms,ax,lines] = create_figure(opts,@on_key,@on_close);
    opts.scalevals = [10 20 50 100 200 500 1000 ];
    opts.scalepos  = 4;
    
    %scale
    hh = 0.94;
    offset = 0.09;
    cb_stream = '';
    streamnames2 = cellfun(@(x)[x ' stream'], streamnames, 'uniformoutput', false);
    opts.streamui = uicontrol('unit', 'normalized', 'position', [0.02 hh 0.15 0.05], 'style', 'popupmenu', 'string', streamnames2, 'callback', cb_stream);
    uicontrol('unit', 'normalized', 'position', [0.09+offset hh-0.01 0.08 0.05], 'style', 'text', 'string', 'scale:');
    uicontrol('unit', 'normalized', 'position', [0.22+offset hh-0.01 0.08 0.05], 'style', 'text', 'string', 'uV');
    opts.scaleui = uicontrol('unit', 'normalized', 'position', [0.16+offset hh 0.08 0.05], 'style', 'edit', 'string', num2str(opts.datascale));
    
    % record button
    if opts.recordbut
        cb_record = [   'if isequal(get(gcbo, ''string''), ''Record''),' ...
                        '    set(gcbo, ''string'', ''Stop'');' ...
                        '    warndlg([ ''Your RAM should be able to hold the entire data.'' 10 ''When you press stop, you will be prompted to save the data.'' ]);' ...
                        '    EEG = [];' ...
                        'else,' ...
                        '    set(gcbo, ''string'', ''Record'');' ...
                        '    EEG.data = [ EEG.data{:} ];' ...
                        '    EEG.trials = 1;' ...
                        '    EEG.pnts   = size(EEG.data,2);' ...
                        '    [filenametmp, filepathtmp] = uiputfile(''*.set'', ''Save dataset with .set extension'');' ...
                        '    if isequal(filenametmp, 0), return; end;' ...
                        '    try,' ...
                        '        if ~isequal(lower(filenametmp(end-3:end)), ''.set''),' ...
                        '             filenametmp = [ filenametmp ''.set'' ];' ...
                        '        end;' ...
                        '        save(''-mat'', fullfile(filepathtmp, filenametmp), ''EEG'');' ...
                        '        disp(''Dataset saved'');' ...
                        '    catch,' ...
                        '        errordlg([''Cannot save data file.'' 0 ''EEG data is still in the EEG variable'' 0 ''in the global workspace.'' ]);' ...
                        '    end;' ...
                        '    clear filenametmp, filepathtmp;' ...
                        'end;' ];
        opts.recordui  = uicontrol('unit', 'normalized', 'position', [0.87 0.05 0.10 0.10], 'style', 'pushbutton', 'string', 'Record', 'callback', cb_record, 'userdata', 0);
    end
    
    % optionally design a frequency filter
    valFilter = 1;
    strFilter = { 'No filter' 'BP 2-30Hz' 'BP 2-45Hz' 'BP 5-45Hz' 'BP 15-45Hz' 'BP 7-13Hz' };
    allBs = { [] };
    if stream.srate > 100
        allBs{end+1} = design_bandpass([1  2 29 31],stream.srate,20,true);
        allBs{end+1} = design_bandpass([1  2 45 47],stream.srate,20,true);
        allBs{end+1} = design_bandpass([4  5 45 47],stream.srate,20,true);
        allBs{end+1} = design_bandpass([14 15 45 47],stream.srate,20,true);
        allBs{end+1} = design_bandpass([ 6 7 13 14],stream.srate,20,true);
        
        if length(opts.freqfilter) == 4
            allBs{end+1} = design_bandpass(opts.freqfilter,stream.srate,20,true);
            strFilter{end+1} = sprintf('BP %1.0f-%1.0fHz', opts.freqfilter(2), opts.freqfilter(3));
            valFilter = 6;
        elseif isscalar(opts.freqfilter) 
            if opts.freqfilter ~= 0
                allBs{end+1} = ones(opts.freqfilter,1)/max(1,opts.freqfilter);
                strFilter{end+1} = 'Moving av.';
                valFilter = 6;
            end
        else
            error('The FIR filter must be given as 4 frequencies in Hz [raise-start,raise-stop,fall-start,fall-stop] or moving-average length in samples.');
        end
    end
    opts.filterui = uicontrol('unit', 'normalized', 'position', [0.30+offset hh 0.18 0.05], 'style', 'popupmenu', 'string', strFilter, 'value', valFilter);
    
    % other options
    opts.rerefui  = uicontrol('unit', 'normalized', 'position', [0.48+offset hh 0.15 0.05], 'style', 'checkbox', 'string', 'Ave Ref', 'value', opts.reref);
    opts.normui   = uicontrol('unit', 'normalized', 'position', [0.61+offset hh 0.11 0.05], 'style', 'checkbox', 'string', 'Norm.', 'value', opts.standardize);
    opts.zeroui   = uicontrol('unit', 'normalized', 'position', [0.73+offset hh 0.22 0.05], 'style', 'checkbox', 'string', 'Zero mean', 'value', opts.zeromean);
    
    % filtering UI
%     B50 = design_bandpass(opts.freqfilter,stream.srate,20,true);
%     valGui
%     if ~isempty(opts.notch)
%         if opts.notch == 50, valGui = 2; end
%         if opts.notch == 60, valGui = 3; end
%     end
%    opts.notchfilterui  = uicontrol('unit', 'normalized', 'position', [0.25 0.945 0.18 0.05], 'style', 'popupmenu', 'string', { 'No notch' 'Notch 50Hz' 'Notch 60Hz' }, 'value', valGui, 'userdata', );

    % start a timer that reads from LSL and updates the display
    th = timer('TimerFcn',@on_timer,'Period',1.0/opts.refreshrate,'ExecutionMode','fixedRate');
    start(th);
else
    % bring up GUI dialog if no arguments were passed (calls the function again)
    arg_guidialog;
end

    % update display with new data
    function on_timer(varargin)
        global EEG;
        try 
            currentlyRecording = false;
            if opts.recordbut
                % get recording status
                strRecord = get(opts.recordui, 'string');
                if isequal(strRecord, 'Stop')
                    currentlyRecording = true;
                end
            end
            
            % switch stream
            if ~isequal(opts.streamname, streamnames{get(opts.streamui, 'value')})
                if ~currentlyRecording
                    opts.streamname = streamnames{get(opts.streamui, 'value')};
                    inlet = create_inlet(lib,opts);
                    stream = create_streambuffer(opts,inlet.info()); 
                    lines = [];
                else
                    disp('Cannot switch stream while recording');
                    streamPos = strmatch(opts.streamname, streamnames, 'exact');
                    set(opts.streamui, 'value', streamPos);
                end
            end
            
            % pull a new chunk from LSL
            [chunk,timestamps] = inlet.pull_chunk();
            if isempty(chunk)
                return; end
            
            % optionally filter the chunk
            chunk(~isfinite(chunk(:))) = 0;
            oriChunk = chunk;
            B = allBs{get(opts.filterui, 'value')};
            if ~isempty(B)
                [chunk,stream.state] = filter(B,1,chunk,stream.state,2); end

            % get scale
            tmpscale = str2double(get(opts.scaleui, 'string'));
            if length(tmpscale) == 1, opts.datascale = tmpscale; end

            % append it to the stream buffer
            [stream.nsamples,stream.buffer(:,1+mod(stream.nsamples:stream.nsamples+size(chunk,2)-1,size(stream.buffer,2)))] = deal(stream.nsamples + size(chunk,2),chunk);

            % extract channels/samples to plot
            samples_to_get = min(size(stream.buffer,2), round(stream.srate*opts.timerange));
            channels_to_get = intersect(opts.channelrange + opts.pageoffset*length(opts.channelrange), 1:size(stream.buffer,1));
            stream.data = stream.buffer(channels_to_get,1+floor(mod(stream.nsamples-samples_to_get: stream.srate/opts.samplingrate : stream.nsamples-1,size(stream.buffer,2))));
            [stream.nbchan,stream.pnts,stream.trials] = size(stream.data);
            stream.xmax = max(timestamps) - lsl_local_clock(lib);
            stream.xmin = stream.xmax - (samples_to_get-1)/stream.srate;
            
            % save as EEG dataset
            if opts.recordbut
                if currentlyRecording
                    if isempty(EEG)
                        EEG.nbchan = stream.nbchan;
                        EEG.xmin  = 0;
                        EEG.xmax  = 0;
                        EEG.srate = stream.srate;
                        EEG.data = {};
                        EEG.setname     = '';
                        EEG.filename    = '';
                        EEG.filepath    = '';
                        EEG.subject     = '';
                        EEG.group       = '';
                        EEG.condition   = '';
                        EEG.session     = [];
                        EEG.comments    = '';
                        EEG.times       = [];
                        EEG.icaact      = [];
                        EEG.icawinv     = [];
                        EEG.icasphere   = [];
                        EEG.icaweights  = [];
                        EEG.icachansind = [];
                        EEG.chanlocs    = [];
                        EEG.urchanlocs  = [];
                        EEG.chaninfo    = [];
                        EEG.ref         = [];
                        EEG.event       = [];
                        EEG.urevent     = [];
                        EEG.eventdescription = {};
                        EEG.epoch       = [];
                        EEG.epochdescription = {};
                        EEG.reject      = [];
                        EEG.stats       = [];
                        EEG.specdata    = [];
                        EEG.specicaact  = [];
                        EEG.splinefile  = '';
                        EEG.icasplinefile = '';
                        EEG.dipfit      = [];
                        EEG.history     = '';
                        EEG.saved       = 'no';
                        EEG.etc         = [];
                    end
                    if ~iscell(EEG.data)
                        EEG.data = {};
                    end
                    EEG.data{end+1} = oriChunk;
                end
            end
            
            % optionally post-process the data
            if get(opts.rerefui, 'value')
                stream.data = bsxfun(@minus,stream.data,mean(stream.data)); end
            if get(opts.normui, 'value')
                stream.data = bsxfun(@times,stream.data,1./std(stream.data,[],2)); end
            if get(opts.zeroui, 'value')
                stream.data = bsxfun(@minus, stream.data, mean(stream.data,2)); end

            % arrange for plotting
            plotoffsets = (0:stream.nbchan-1)'*opts.datascale;
            plotdata = bsxfun(@plus, stream.data, plotoffsets);
            plottime = linspace(stream.xmin,stream.xmax,stream.pnts);
            
            % update graphics
            if isempty(lines)    
                lines = plot(ax,plottime,plotdata);
                xlabel(ax,sprintf('Time (%1.1f sec)',opts.timerange) ,'FontSize',12);
                ylabel(ax,'Activation','FontSize',12);
            else
                for k=1:min(length(lines),size(plotdata,1))
                    set(lines(k),'Xdata',plottime, 'Ydata',plotdata(k,:)); end
                for k = size(plotdata,1)+1:length(lines)
                    set(lines(k),'Ydata',nan(stream.pnts,1)); end
            end
            
            % update the axis limit and tickmarks
            axis(ax   ,[stream.xmin stream.xmax -opts.datascale stream.nbchan*opts.datascale + opts.datascale]);
            set(ax, 'YTick',plotoffsets, 'YTickLabel',{stream.chanlocs(channels_to_get).labels});
            set(ax, 'XTick',[], 'XTickLabel',[]);
            
            % compute RMS and show it
            if opts.rms
                axis(axrms,[stream.xmin stream.xmax -opts.datascale stream.nbchan*opts.datascale + opts.datascale]);
                rmsdata = plotdata(:, round(size(plotdata,2)*opts.rmsrange/opts.timerange):end);
                rms = sqrt(mean(bsxfun(@minus, rmsdata, mean(rmsdata,2)).^2,2));
                rmsStr = {};
                for iRms = 1:length(rms)
                    rmsStr{iRms} = sprintf('%2.1f uVrms', rms(iRms));
                end
                set(axrms, 'YTick',plotoffsets, 'YTickLabel',rmsStr);
                set(axrms, 'XTick',[], 'XTickLabel',[]);
            end
            drawnow;
        catch e
            % display error message
            fprintf('vis_stream error: %s\noccurred in:\n',e.message);
            for st = e.stack'
                if ~isdeployed
                    try
                        fprintf('   <a href="matlab:opentoline(''%s'',%i)">%s</a>: %i\n',st.file,st.line,st.name,st.line);
                    catch
                        fprintf('   <a href="matlab:edit %s">%s</a>: %i\n',st.file,st.name,st.line);
                    end
                else
                    fprintf('   %s: %i\n',st.file,st.line);
                end
            end
            on_close();
        end
    end

    % handle key presses
    function on_key(key)
        switch lower(key)
            case 'uparrow' % decrease datascale                
                opts.datascale = round(opts.datascale*0.9); set(opts.scaleui, 'string', num2str(opts.datascale));
            case 'downarrow' % increase datascale                
                opts.datascale = round(opts.datascale*1.1); set(opts.scaleui, 'string', num2str(opts.datascale));
            case 'rightarrow' % increase timerange                
                opts.timerange = opts.timerange*1.1;                
            case 'leftarrow' % decrease timerange                
                opts.timerange = opts.timerange*0.9;                
            case 'pagedown' % shift display page offset down                
                opts.pageoffset = min(opts.pageoffset+1,ceil(size(stream.buffer,1)/numel(opts.channelrange))-1);
            case 'pageup' % shift display page offset up                
                opts.pageoffset = max(opts.pageoffset-1,0);
        end
    end

    % close figure, timer and stream
    function on_close(varargin)
        try
            delete(fig);
            stop(th);
            delete(th);
        catch
            delete(gcf);
        end
    end

end

% find names of streams on the lab network
function names = find_streams(lib)
    streams = lsl_resolve_all(lib,0.3);
    names = unique(cellfun(@(s)s.name(),streams ,'UniformOutput',false));
end

% create a new figure and axes
function [fig,axrms,ax,lines] = create_figure(opts,on_key,on_close)
    axrms = [];
    if isempty(opts.parent_ax)
        if isempty(opts.parent_fig)
            fig = figure('Name',['LSL:Stream''' opts.streamname ''''], 'CloseRequestFcn',on_close, ...
                'KeyPressFcn',@(varargin)on_key(varargin{2}.Key), 'menubar', 'none', 'numbertitle', 'off');
            %fig = figure('Name',['LSL:Stream''' opts.streamname '''']);
        else
            fig = opts.parent_fig;
        end
        if opts.rms
            axrms = axes('Parent',fig, 'YAxisLocation', 'right', 'YDir','normal', 'position', [0.1300    0.1100    0.7050    0.8150]);
        end
        ax    = axes('Parent',fig, 'unit', 'normalized', 'YDir','normal', 'position', [0.1300    0.1100    0.7050    0.8150], 'visible', 'on');
    else
        ax = opts.parent_ax;
    end       
    lines = [];
end

% create an inlet to read from the stream with the given name
function inlet = create_inlet(lib,opts)
    % look for the desired device
    result = {};
    disp(['Looking for a stream with name=' opts.streamname ' ...']);
    while isempty(result)
        result = lsl_resolve_byprop(lib,'name',opts.streamname); end
    % create a new inlet
    disp('Opening an inlet...');
    inlet = lsl_inlet(result{1},opts.bufferrange);
end

% create a new stream buffer to hold our data
function stream = create_streambuffer(opts,info)
    stream.srate = info.nominal_srate();
    stream.chanlocs = struct('labels',derive_channel_labels(info));
    stream.buffer = zeros(length(stream.chanlocs),max(max(opts.bufferrange,opts.timerange)*stream.srate,100));
    [stream.nsamples,stream.state] = deal(0,[]);
end

% derive a list of channel labels for the given stream info
function channels = derive_channel_labels(info)
    channels = {};
    ch = info.desc().child('channels').child('channel');
    while ~ch.empty()
        name = ch.child_value_n('label');
        if name
            channels{end+1} = name; end %#ok<AGROW>
        ch = ch.next_sibling_n('channel');
    end
    if length(channels) ~= info.channel_count()
        disp('The number of channels in the steam does not match the number of labeled channel records. Using numbered labels.');
        channels = cellfun(@(k)['Ch' num2str(k)],num2cell(1:info.channel_count(),1),'UniformOutput',false);
    end
end


% === utility functions for signal processing ===

% design a bandpass filter
function B = design_bandpass(freqs,srate,atten,minphase)
    % get frequencies and amplitudes
    freqs = min(freqs*2/srate,0.95);
    % design Kaiser window for smallest transition band
    [dummy,pos] = min(diff(freqs)); %#ok<ASGLU>
    wnd = design_kaiser(freqs(pos),freqs(pos+1),atten,false);
    % design FIR filter with that window
    B = design_fir(length(wnd)-1,[0 freqs 1],[0 0 1 1 0 0],[],wnd);
    % transform to minimum-phase design
    if minphase
        n = length(B);
        wnd = [1 2*ones(1,(n+mod(n,2))/2-1) ones(1,1-mod(n,2)) zeros(1,(n+mod(n,2))/2-1)];
        B = real(ifft(exp(fft(wnd.*real(ifft(log(abs(fft(B))+10^(-atten/10))))))));
    end
end

% design an FIR filter using the frequency-sampling method
function B = design_fir(N,F,A,nfft,W,odd)
    if nargin < 4 || isempty(nfft)
        nfft = max(512,2^ceil(log(N)/log(2))); end
    if nargin < 5
        W = 0.54 - 0.46*cos(2*pi*(0:N)/N); end
    if nargin < 6
        odd = false; end
    % calculate interpolated frequency response
    F = interp1(round(F*nfft),A,(0:nfft),'pchip');
    % set phase & transform into time domain
    F = F .* exp(-(0.5*N)*sqrt(-1)*pi*(0:nfft)./nfft);
    if odd 
        F = F.*(-i); end %#ok<IJCL>
    B = real(ifft([F conj(F(end-1:-1:2))]));
    % apply window to kernel
    B = B(1:N+1).*W(:)';
end

% design a Kaiser window for a low-pass FIR filter
function W = design_kaiser(lo,hi,atten,odd)
    % determine beta parameter of the window
    if atten < 21
        beta = 0;
    elseif atten <= 50
        beta = 0.5842*(atten-21).^0.4 + 0.07886*(atten-21);
    else
        beta = 0.1102*(atten-8.7);
    end
    % determine the number of points
    N = round((atten-7.95)/(2*pi*2.285*(hi-lo)))+1;
    if odd && ~mod(N,2)
        N = N+1; end
    % design the window
    W = besseli(0,beta*sqrt(1-(2*((0:(N-1))/(N-1))-1).^2))/besseli(0,beta);
end
