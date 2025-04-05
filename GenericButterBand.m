function filtered_data = GenericButterBand(f_low, f_high, fs, data_segment, options)
    %GenericBu  tterBand Apply a Butterworth bandpass filter to a data segment.
    %
    %   filtered_data = GenericButterBand(f_low, f_high, fs, data_segment)
    %   applies a 4th-order Butterworth bandpass filter to the input
    %   data_segment. The passband is defined between f_low and f_high (Hz).
    %   The data is assumed to be sampled at fs Hz. Filtering is performed
    %   using filtfilt for zero phase distortion.
    %
    %   filtered_data = GenericButterBand(f_low, f_high, fs, data_segment, Name, Value)
    %   allows specifying optional parameters using Name-Value pairs.
    %
    %   Inputs:
    %       f_low        - Lower cutoff frequency of the passband (Hz). Must be > 0.
    %       f_high       - Upper cutoff frequency of the passband (Hz). Must be > f_low.
    %       fs           - Sampling frequency (Hz). Must be > 0.
    %       data_segment - Input data vector (row or column). Can also be a matrix,
    %                      where filtering occurs column-wise.
    %
    %   Optional Name-Value Pairs:
    %       'Order'      - The order of the Butterworth filter. Default is 4.
    %                      Higher orders provide sharper cutoffs but may increase
    %                      transients or numerical stability issues. Must be a
    %                      positive integer.
    %
    %   Outputs:
    %       filtered_data - The filtered data, having the same dimensions
    %                       as the input data_segment.
    %
    %   Requires: Signal Processing Toolbox.
    %
    %   Example Usage:
    %       % --- Setup ---
    %       fs = 250; % Hz
    %       t = (0:1/fs:2)'; % 2 seconds duration
    %       % Signal components: 10Hz (stop), 32Hz (pass), 60Hz (stop)
    %       signal = 0.8*sin(2*pi*10*t) + 1.0*sin(2*pi*32*t) + 0.6*sin(2*pi*60*t);
    %       noise = 0.15*randn(size(t));
    %       my_data = signal + noise;
    %
    %       % --- Filtering ---
    %       % Filter between 27 Hz and 37 Hz with default order 4
    %       band_2737_default = GenericButterBand(27, 37, fs, my_data);
    %
    %       % Filter between 27 Hz and 37 Hz with order 6
    %       band_2737_order6 = GenericButterBand(27, 37, fs, my_data, 'Order', 6);
    %
    %       % --- Plotting ---
    %       figure;
    %       ax1 = subplot(3,1,1); plot(t, my_data); title('Original Signal'); ylabel('Amplitude'); grid on;
    %       ax2 = subplot(3,1,2); plot(t, band_2737_default); title('Filtered (27-37 Hz, Order 4)'); ylabel('Amplitude'); grid on;
    %       ax3 = subplot(3,1,3); plot(t, band_2737_order6); title('Filtered (27-37 Hz, Order 6)'); ylabel('Amplitude'); grid on;
    %       xlabel(ax3, 'Time (s)');
    %       linkaxes([ax1, ax2, ax3], 'x'); % Link x-axes for easier comparison
    
        % --- Input Argument Parsing and Validation ---
        % Uses the 'arguments' block for concise validation (R2019b+)
        arguments
            f_low (1,1) double {mustBeNumeric, mustBePositive, mustBeFinite}
            f_high (1,1) double {mustBeNumeric, mustBePositive, mustBeFinite}
            fs (1,1) double {mustBeNumeric, mustBePositive, mustBeFinite}
            data_segment {mustBeNumeric, mustBeNonempty, mustBeFinite} % Allow vector or matrix
            options.Order (1,1) double {mustBeInteger, mustBePositive} = 4 % Default order for Butterworth
        end
    
        % Additional custom validation
        if f_low >= f_high
            error('GenericButterBand:InvalidFrequencyRange', 'Low cutoff frequency (f_low=%.2f) must be less than high cutoff frequency (f_high=%.2f).', f_low, f_high);
        end
        nyquist_freq = fs / 2;
        if f_high >= nyquist_freq
             error('GenericButterBand:FrequencyTooHigh', 'High cutoff frequency (f_high=%.2f Hz) must be less than the Nyquist frequency (fs/2=%.2f Hz).', f_high, nyquist_freq);
        end
        % f_low > 0 is checked by mustBePositive
    
        % Get filter order from parsed options
        filter_order = options.Order;
    
        % --- Design the Butterworth Bandpass Filter ---
        Wn = [f_low, f_high] / nyquist_freq; % Normalize frequencies
    
        % Get filter coefficients [b (numerator), a (denominator)]
        try
            [b, a] = butter(filter_order, Wn, 'bandpass');
        catch ME
            error('GenericButterBand:FilterDesignFailed', 'Failed to design Butterworth filter. Error: %s', ME.message);
        end
    
        % --- Apply the Filter to the Data Segment ---
        % Ensure data is double precision for filtfilt
        if ~isa(data_segment, 'double')
            try
                 data_segment_double = double(data_segment);
            catch ME
                error('GenericButterBand:CannotConvertToDouble', 'Input data segment could not be converted to double precision for filtering. Original error: %s', ME.message);
            end
            % Optional: Warn user about conversion
            % warning('GenericButterBand:DataTypeConverted', 'Input data segment converted to double precision for filtering.');
        else
            data_segment_double = data_segment;
        end
    
        % Apply filtfilt for zero-phase filtering.
        % filtfilt applies the filter along the first non-singleton dimension,
        % which is typically columns for matrices. This behavior is generally desired.
        try
            filtered_data = filtfilt(b, a, data_segment_double);
        catch ME
            % Check for common NaN/Inf issues if filtfilt fails
            if any(isnan(data_segment_double(:))) || any(isinf(data_segment_double(:)))
                 error('GenericButterBand:InvalidDataValues', 'Input data segment contains NaN or Inf values, which filtfilt cannot handle. Please clean the data before filtering.');
            else
                 error('GenericButterBand:FilteringFailed', 'Filtering with filtfilt failed. Error: %s', ME.message);
            end
        end
    
        % Optional: Cast back to original data type if needed, though typically
        % numerical results are kept in double.
        % if ~isa(data_segment, 'double')
        %     filtered_data = cast(filtered_data, 'like', data_segment);
        % end
    
    end