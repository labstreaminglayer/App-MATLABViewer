% This function allow calling vis_stream with simply a string of character
% so it can be used to set parameters after being compiled. Make sure there
% are no spaces for parameter values or the string will not be parsed
% properly.
%
% Example: vis_stream_comp('samplingrate 200 refreshrate 5 position [100,100,500,500]');

function vis_stream_comp(varargin)

% parse parameters
if nargin == 1 && ischar(varargin{1})
    strparams = varargin{1};
    opt = textscan(strparams, '%s');
    opt = opt{1};
    for iOpt = 1:length(opt)
        if opt{iOpt}(1) == '-'
            opt{iOpt} = opt{iOpt}(2:end);
        end
        indminus = find(opt{iOpt} == '-');
        for iIndminus = 1:length(indminus)
            if opt{iOpt}(indminus(iIndminus)-1) == ' '
                opt{iOpt}(indminus(iIndminus)) = '_';
            end
        end
    end
    opt = struct(opt{:});
elseif nargin == 1 && isstruct(varargin{1})
    opt = varargin{1};
elseif nargin > 1
    opt = struct(varargin{:});
else
    opt = struct([]);
end
    
numFields  = { 'bufferrange' 'timerange' 'channelrange' 'samplingrate' 'refreshrate' 'freqfilter' 'position' 'reref' 'standardize' 'zeromean' 'recordbut' };

for iField = 1:length(numFields)
    if isfield(opt, numFields{iField}) && ischar(opt.(numFields{iField})) 
        opt.(numFields{iField}) = strrep(opt.(numFields{iField}), '_', ' ');
        opt.(numFields{iField}) = str2num(opt.(numFields{iField})); % will convert booleans as well
    end
end

fieldNames = fieldnames(opt);
fieldValues = struct2cell(opt);
fieldNames(:,2) = fieldValues;
fieldNames = fieldNames';
fieldNames = fieldNames(:)';

vis_stream(fieldNames{:});
