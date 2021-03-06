classdef IsosurfaceOptionsDialog < handle
%ISOSURFACEOPTIONSDIALOG Dialog for 3D isosurfaces of intensity images
%
%   Class IsosurfaceOptionsDialog
%
%   Example
%   IsosurfaceOptionsDialog
%
%   See also
%     IsosurfaceOptionsDialog
%

% ------
% Author: David Legland
% e-mail: david.legland@inra.fr
% Created: 2013-04-19,    using Matlab 7.9.0.529 (R2009b)
% Copyright 2013 INRA - Cepia Software Platform.


%% Properties
properties
    isosurfaceValue = 0;
    
    parent;
    
    handles;
end % end properties


%% Constructor
methods
    function this = IsosurfaceOptionsDialog(parent, varargin)
    % Constructor for IsosurfaceOptionsDialog class
        
         % call parent constructor to initialize members
        this = this@handle();
        this.parent = parent;

        % pre-compute initial value of isosurface (from Otsu threshold)
        this.isosurfaceValue = imOtsuThreshold(this.parent.imageData);
        
        
        % create default figure
        fig = figure(...
            'MenuBar', 'none', ...
            'NumberTitle', 'off', ...
            'HandleVisibility', 'On', ...
            'Name', 'Isosurface Options', ...
            'CloseRequestFcn', @this.close);
        this.handles.figure = fig;
            
        setupLayout(fig);
        
        function setupLayout(hf)
            % Setup layout of figure widgets
       
            pos = get(hf, 'Position');
            pos(3:4) = [200 180];
            set(hf, 'Position', pos);
            set(hf, 'Units', 'normalized');
            
            if verLessThan('matlab', 'R2014b')
                mainPanel = uiextras.VBox('Parent', hf);
            else
                mainPanel = uix.VBox('Parent', hf);
            end
            
            % control panel: use vertical layout
            if verLessThan('matlab', 'R2014b')
                optionsPanel = uiextras.VButtonBox('Parent', mainPanel, ...
                    'ButtonSize', [150 30], ...
                    'VerticalAlignment', 'top', ...
                    'HorizontalAlignment', 'center', ...
                    'Spacing', 5, 'Padding', 5);
            else
                optionsPanel = uix.VButtonBox('Parent', mainPanel, ...
                    'ButtonSize', [150 30], ...
                    'VerticalAlignment', 'top', ...
                    'HorizontalAlignment', 'center', ...
                    'Spacing', 5, 'Padding', 5);
            end

            this.handles.thresholdText = uicontrol(...
                'Style', 'text', 'Parent', optionsPanel, ...
                'String', 'Isosurface Value:', ...
                'HorizontalAlignment', 'Left');

            this.handles.isosurfaceValue = uicontrol(...
                'Style', 'edit', 'Parent', optionsPanel, ...
                'String', num2str(this.isosurfaceValue), ...
                'Value', 1, ...
                'HorizontalAlignment', 'Left');
            
            this.handles.reverseZAxis = uicontrol(...
                'Style', 'checkbox', 'Parent', optionsPanel, ...
                'String', 'Reverse Z-axis', ...
                'Value', 1, ...
                'HorizontalAlignment', 'Left');

            this.handles.rotateOx = uicontrol(...
                'Style', 'checkbox', 'Parent', optionsPanel, ...
                'String', 'Rotate around X-axis', ...
                'Value', 1, ...
                'HorizontalAlignment', 'Left');

            this.handles.smooth = uicontrol(...
                'Style', 'checkbox', 'Parent', optionsPanel, ...
                'String', 'Smooth', ...
                'Value', 1, ...
                'HorizontalAlignment', 'Left');
            
            this.handles.showAxisLabel = uicontrol(...
                'Style', 'checkbox', 'Parent', optionsPanel, ...
                'String', 'Show axes label', ...
                'Value', 0, ...
                'HorizontalAlignment', 'Left');
            
            % add control panel with "Compute" and "Close" buttons
            if verLessThan('matlab', 'R2014b')
                buttonsPanel = uiextras.HButtonBox('Parent', mainPanel, ...
                    'ButtonSize', [70 30], ...
                    'VerticalAlignment', 'top', ...
                    'Spacing', 5, 'Padding', 5, ...
                    'Units', 'normalized', ...
                    'Position', [0 0 1 1]);
            else
                buttonsPanel = uix.HButtonBox('Parent', mainPanel, ...
                    'ButtonSize', [70 30], ...
                    'VerticalAlignment', 'top', ...
                    'Spacing', 5, 'Padding', 5, ...
                    'Units', 'normalized', ...
                    'Position', [0 0 1 1]);
            end
            
            this.handles.applyButton = uicontrol('Style', 'PushButton', ...
                'Parent', buttonsPanel, ...
                'String', 'Compute', ...
                'Enable', 'on', ...
                'Callback', @this.onApplyButtonClicked);
            this.handles.closeButton = uicontrol('Style', 'PushButton', ...
                'Parent', buttonsPanel, ...
                'String', 'Close', ...
                'Callback', @this.close);
            
            if verLessThan('matlab', 'R2014b')
                mainPanel.Sizes = [-1 40];
            else
                mainPanel.Heights = [-1 40];
            end

        end
    end

end % end constructors


%% Methods
methods
    function onApplyButtonClicked(this, hObject, eventdata) %#ok<INUSD>
        
        % first, disable "compute" button to avoid multiple calls
        set(this.handles.applyButton, 'enable', 'off');
        hDlg = msgbox({'Computing isosurfaces,', 'Please wait...'}, ...
            'Isosurface computing');
        
        % extract options from widgets
        str = get(this.handles.isosurfaceValue, 'String');
        [value, flag] = str2num(str); %#ok<ST2NM>
        if ~flag
            error(['Could not parse isosurface value from: ' str]);
        end
        reverseZAxis = get(this.handles.reverseZAxis, 'Value');
        rotateXAxis = get(this.handles.rotateOx, 'Value');
        smooth = get(this.handles.smooth, 'Value');
        showAxesLabel = get(this.handles.showAxisLabel, 'Value');
        
        % get image data stored in parent Slicer
        imgData = this.parent.imageData;
        imgSize = this.parent.imageSize;
        
        % avoid the case of empty image
        if isempty(imgData)
            return;
        end
        
        % eventually rotate image around X-axis
        if rotateXAxis
            imgData = stackRotate90(imgData, 'x', 1);
            imgSize = imgSize([1 3 2]);
        end
        
        % compute display settings
        spacing = this.parent.voxelSize;
        origin  = this.parent.voxelOrigin;
        
        % compute grid positions
        lx = (0:imgSize(1)-1) * spacing(1) + origin(1);
        ly = (0:imgSize(2)-1) * spacing(2) + origin(2);
        lz = (0:imgSize(3)-1) * spacing(3) + origin(3);

        if rotateXAxis
            ly = ly(end:-1:1);
        end

        % determine the color map to use (default is empty)
        cmap = [];
        if ~isColorStack(imgData) && ~isempty(this.parent.colorMap)
            cmap = this.parent.colorMap;
        end
        if isempty(cmap)
            cmap = jet(256);
        end
        
        % create figure 
        hf = figure(); hold on;
        set(hf, 'renderer', 'opengl');
        
        % compute isosurface
        im = imgData >= value;
        if ~any(im)
            return;
        end
        
        if smooth
            im = imGaussianFilter(double(im), [5 5 5], 2);
        end
        
        % display isosurface
        p = patch(isosurface(lx, ly, lz, im, .5));
        
        % set face color
        set(p, 'FaceColor', cmap(end,:), 'EdgeColor', 'none');
        
        % compute display extent (add a 0.5 limit around each voxel)
        extent = stackExtent(imgSize, spacing, origin);
        
        % setup display
        axis equal;
        axis(extent);
        view(3);
        axis('vis3d');
        
        light;
         
        if rotateXAxis || reverseZAxis
            set(gca, 'zdir', 'reverse');
        end
        
        if showAxesLabel
            xlabel('X axis');
            if rotateXAxis
                ylabel('Z Axis');
                zlabel('Y Axis');
            else
                ylabel('Y Axis');
                zlabel('Z Axis');
            end
        end
        
        % re-enable "apply" button
        set(this.handles.applyButton, 'enable', 'on');
        if ishandle(hDlg)
            close(hDlg);
        end

    end
    
end % end methods

%% Figure management
methods
    function close(this, varargin)
        delete(this.handles.figure);
    end
    
end

end % end classdef

