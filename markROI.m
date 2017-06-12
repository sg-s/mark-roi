% markROI.m
% marks rois in an image sequence
% will work on .mat files that contain a variable called "images" that is a 3D matrix (monochrome images only)
% .mat files should be v7.3 or later, as markROI only partially loads files to speed up the UI
% 
% 
% created by Srinivas Gorur-Shandilya at 12:17 , 03 December 2015. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.ts
classdef markROI < handle

properties
    handles
    nframes
    current_file = 1;
    matfile_handle 
    variable_name = 'images';
    folder_name
    allfiles

    % for activity-correlated imaging
    pre_stimulus_epoch = [40 60];
    stimulus_epoch = [60 120];
    post_stimulus_epoch
    use_time = true; % epochs defines by time vector, not frame numbers?
    time

end % end properties 


methods

    function m = markROI(m)

        % first, get the directory we are going to work in
        m.folder_name = uigetdir(pwd,'Choose a folder containing .mat files of the videos you want to work on');
        m.folder_name = [m.folder_name oss];

        % get all image files in this
        m.allfiles = dir([m.folder_name '*.mat']);
        % remove files that begin with a dot
        m.allfiles(cellfun(@(x) strcmp(x(1),'.'),{m.allfiles.name})) = [];

        assert(length(m.allfiles)>0,'No files found! Make you are in a folder with some .mat files"')

        m.makeUI;

        m.loadFile(1);


    end % end creator function 

    function makeUI(m,~,~)
        handles.fig = figure('outerposition',[100 50 600 800],'NumberTitle','off','Name','markROI','Toolbar','none','Menubar','none');
        handles.ax1 = axes('parent',handles.fig,'Position',[0.05 0.3 0.9 0.65]); hold on
        handles.im = imagesc(handles.ax1,zeros(256,256));
        colormap gray
        handles.scrubber = uicontrol(handles.fig,'Units','normalized','Position',[.05 .15 .9 .1],'Style', 'slider','FontSize',12,'Callback',@m.showFrame);
        try    % R2013b and older
           addlistener(handles.scrubber,'ActionEvent',@m.showFrame);
        catch  % R2014a and newer
           addlistener(handles.scrubber,'ContinuousValueChange',@m.showFrame);
        end

        handles.next_file = uicontrol(handles.fig,'Units','normalized','Position',[.90 .01 .1 .05],'Style', 'pushbutton','FontSize',12,'String','>','Callback',@m.loadFile);
        handles.prev_file = uicontrol(handles.fig,'Units','normalized','Position',[.0 .01 .1 .05],'Style', 'pushbutton','FontSize',12,'String','<','Callback',@m.loadFile);

        handles.max_proj = uicontrol(handles.fig,'Units','normalized','Position',[.05 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','Max. Proj.','Callback',@m.maxProj);

        handles.std_proj = uicontrol(handles.fig,'Units','normalized','Position',[.21 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','Std. Proj.','Callback',@m.stdProj);

        handles.aci_button = uicontrol(handles.fig,'Units','normalized','Position',[.37 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','ACI','Callback',@m.showACI);

        handles.timeseries_button = uicontrol(handles.fig,'Units','normalized','Position',[.05 .09 .3 .05],'Style', 'togglebutton','FontSize',12,'String','Show time series','Callback',@m.drawOrEraseTimeSeriesPlot);

        handles.mark_control = uicontrol(handles.fig,'Units','normalized','Position',[.65 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','+Control ROI.','Callback',@m.pickROI);
        handles.mark_test = uicontrol(handles.fig,'Units','normalized','Position',[.80 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','+Test ROI','Callback',@m.pickROI);

        handles.remove_roi = uicontrol(handles.fig,'Units','normalized','Position',[.75 .09 .15 .05],'Style', 'pushbutton','FontSize',12,'String','-ROI','Callback',@m.removeROI);

        m.handles = handles;
    end

    function removeROI(m,~,~)
        m.matfile_handle.control_roi = [];
        m.matfile_handle.test_roi = [];
        m.showFrame;
    end

    function loadFile(m,src,~)
        handles = m.handles;
        set(handles.fig,'Name','markROI')
        if src ~= 1
            if strcmp(src.String,'>')
                load_this = m.current_file + 1;
            elseif strcmp(src.String,'<')
                load_this = m.current_file - 1;
            end
            m.current_file = load_this;
        else
            load_this = src;
            m.current_file = 1;
        end

        if m.current_file == length(m.allfiles)
            set(handles.next_file,'Enable','off')
            set(handles.prev_file,'Enable','on')
        elseif m.current_file == 1
            set(handles.next_file,'Enable','on')
            set(handles.prev_file,'Enable','off')
        else
            set(handles.next_file,'Enable','on')
            set(handles.prev_file,'Enable','on')
        end

        % check if the current file is v7.3; if not, convert it
        if findMATFileVersion([m.folder_name m.allfiles(load_this).name]) ~= 7.3
            convertMATFileTo73([m.folder_name m.allfiles(load_this).name])
        end


        m.matfile_handle = matfile([m.folder_name m.allfiles(load_this).name],'Writable',true);
        set(handles.fig,'Name',m.allfiles(load_this).name);

        % figure out which variable to load
        variable_names = whos(m.matfile_handle);
        if length(variable_names) == 1
            m.variable_name = variable_names(1).name;
        else
            % only retain 3D arrays
            variable_names = variable_names(cellfun(@length,{variable_names.size}) == 3);
            % pick the largest one
            try
                m.variable_name = variable_names(find([variable_names.bytes] == max([variable_names.bytes]))).name;
            catch
                m.handles.im.CData = zeros(50,50,1);
                return
            end
        end

        % determine the number of frames
        [a,b,m.nframes] = size(m.matfile_handle,m.variable_name);
        set(handles.scrubber,'Min',1,'Max',m.nframes,'Value',round(m.nframes/2));

        set(handles.ax1,'XLim',[1 a],'YLim',[1 b])

        m.showFrame;


    end % end loadFile

    function showACI(m,~,~)
        assert(~isempty(m.stimulus_epoch),'You need to specify the stimulus epoch')
        assert(length(m.stimulus_epoch)==2,'Stimulus epoch should be a two element vector, in frame #')
        assert(~isempty(m.pre_stimulus_epoch),'You need to specify the pre-stimulus epoch')
        assert(length(m.pre_stimulus_epoch)==2,'Pre-Stimulus epoch should be a two element vector, in frame #')

        images = double(m.matfile_handle.(m.variable_name));

        if m.use_time
            time = m.matfile_handle.time;
            a1 = find(time > m.pre_stimulus_epoch(1),1,'first');
            z1 = find(time > m.pre_stimulus_epoch(2),1,'first');
            a2 = find(time > m.stimulus_epoch(1),1,'first');
            z2 = find(time > m.stimulus_epoch(2),1,'first');
        else
            error('not coded')
        end


        for i = 1:size(images,1)
            for j = 1:size(images,2)
                % divide by pre-stimulus flourescence
                baseline = mean(images(i,j,a1:z1));
                images(i,j,:) = images(i,j,:)./baseline;
            end
        end


        A = squeeze(0*images(:,:,1));

        for i = 1:size(images,1)
            for j = 1:size(images,2)
                A(i,j) = mean(images(i,j,a2:z2));
            end
        end

        % create a false color image
        I = zeros(size(images,1),size(images,2),3);
        mI = mean(images,3);
        mI = mI - min(min(mI));
        mI = mI/max(max(mI));

        for i = 1:3
            I(:,:,i) = mI;
        end
        I = 1-I;

        A_lo = A; A_lo(A_lo>1) = 1;
        A_hi = A; A_hi(A_hi<1) = 1;
        A_hi = A_hi - 1;
        A_hi = A_hi/max(max(A_hi));
        A_lo = 1- A_lo;
        A_lo = A_lo/max(max(A_lo));

        A_lo = 1-A_lo;
        A_hi = 1-A_hi;

        I(:,:,1) = I(:,:,1).*A_lo;
        I(:,:,2) = I(:,:,2).*A_lo;
        I(:,:,3) = I(:,:,3).*A_hi;
        I(:,:,2) = I(:,:,2).*A_hi;

        m.handles.im.CData = I;


    end % end showACI

    function showFrame(m,~,~)
        this_image = double(m.matfile_handle.(m.variable_name)(:,:,ceil(get(m.handles.scrubber,'Value'))));
        this_image = this_image - min(min(this_image));
        this_image = this_image/max(max(this_image));
        this_image = (repmat(this_image,1,1,3));

        try
            test_rois = sum(m.matfile_handle.test_roi,3);
            this_image(:,:,3) = this_image(:,:,3).*(1-.5*test_rois);
        catch
        end

        try
            control_rois = sum(m.matfile_handle.control_roi,3);
            this_image(:,:,1) = this_image(:,:,1).*(1-.5*control_rois);
        catch
            
        end

        m.handles.im.CData = this_image;

    end % end showFrame

    function maxProj(m,~,~)
        temp = max(m.matfile_handle.(m.variable_name)(:,:,1:50:get(m.handles.scrubber,'Max')),[],3);
        m.handles.im = imagesc(temp);
        caxis([min(min(temp)) max(max(temp))])
    end % end maxPRoj

    function stdProj(m,~,~)
        temp = std(double(m.matfile_handle.(m.variable_name)(:,:,1:50:get(m.handles.scrubber,'Max'))),[],3);
        m.handles.im = imagesc(temp);
        caxis([min(min(temp)) max(max(temp))])
    end % end stdProj

    function pickROI(m,src,~)
        h = imfreehand;
        if any(strfind(src.String,'ontrol'))
            try
                m.matfile_handle.control_roi(:,:,end+1) = createMask(h,m.handles.im);
            catch
                [a,b] = size(createMask(h,m.handles.im));
                m.matfile_handle.control_roi = logical(zeros(a,b,2));
                m.matfile_handle.control_roi(:,:,1) = createMask(h,m.handles.im);
            end
        else
            try
                m.matfile_handle.test_roi(:,:,end+1) = createMask(h,m.handles.im);
            catch
                [a,b] = size(createMask(h,m.handles.im));
                m.matfile_handle.test_roi = logical(zeros(a,b,2));
                m.matfile_handle.test_roi(:,:,1) = createMask(h,m.handles.im);
            end
        end
        delete(h)

    end % end pick ROI

    function drawOrEraseTimeSeriesPlot(m,src,~)
        if src.Value == 1
            src.String = 'Hide time series';
            % now make the UI for the time series
            m.handles.timeseries_fig = figure('outerposition',[700 300 800 500],'NumberTitle','off','Name','Time series','CloseRequestFcn',@m.resetTimeSeriesButton);
            m.handles.timeseries_ax = axes(m.handles.timeseries_fig);
            hold(m.handles.timeseries_ax,'on')
            xlabel(m.handles.timeseries_ax,'Frame #')
            ylabel(m.handles.timeseries_ax,'Intensity (a.u.)')
            set(m.handles.timeseries_ax,'XLim',[1 m.nframes])

            % plot the time series
            variable_names = whos(m.matfile_handle);
            I = double(m.matfile_handle.(m.variable_name));
            if any(strcmp({variable_names.name},'control_roi'))
                control_roi = m.matfile_handle.control_roi;
                for i = 1:size(control_roi,3)
                    try
                        plot(m.handles.timeseries_ax,squeeze(sum(sum(repmat(control_roi(:,:,i),1,1,m.nframes).*I))),'k');
                    catch
                    end
                end
            end
            if any(strcmp({variable_names.name},'test_roi'))
                test_roi = m.matfile_handle.test_roi;
                for i = 1:size(test_roi,3)
                    try
                        plot(m.handles.timeseries_ax,squeeze(sum(sum(repmat(test_roi(:,:,i),1,1,m.nframes).*I))),'r');
                    catch
                    end
                end
            end
        else
            src.String = 'Show time series';
            try
                delete(m.handles.timeseries_fig)
            catch
            end
        end
    end

    function resetTimeSeriesButton(m,src,~)
        m.handles.timeseries_button.Value = 0;
        m.handles.timeseries_button.String = 'Show time series';
        delete(m.handles.timeseries_fig)
    end



end % end methods

end % end classdef